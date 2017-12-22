#!/bin/bash

# Fail hard and fast
set -eo pipefail

### from ENV parameters (sample)
# GOOGLE_PROJECT_ID="ace-ripsaw-671"
# BIGQUERY_DATASET="watanabe_dataset"
# DATASTORE_NAMESPACE="watanabe"
# INPUT_FILES="gs://classification-data/*/*.gz,gs://classification-data-2/*/*.gz,gs://classification-data-4/*/*.txt,gs://classification-data-data-on-demand/*/*.gz"

# Fixed values
DATASTORE_KIND="user_classification"
DATASTORE_LAST_PROC_KEY="classification_last_proc_info"
DATASTORE_LAST_HASH_PROP="lash_hash"
DATASTORE_LAST_TABLE_PROP="last_proc_table"

# There are a number of options that are global and valid for any Dataflow
# pipeline. This function translates environment variables into the exec.args
# for some of those options.
build_dataflow_exec_args() {
    local exec_args=""

    if [ -n "$GOOGLE_PROJECT_ID" ]; then
        exec_args="$exec_args --project=$GOOGLE_PROJECT_ID"
    fi

    if [ -n "$DATAFLOW_RUNNER" ]; then
        exec_args="$exec_args --runner=$DATAFLOW_RUNNER"
    fi

    # All the functions below set this value, so no need to set default
    if $DATAFLOW_STREAMING; then
        exec_args="$exec_args --streaming"
    fi

    if [ -n "$DATAFLOW_TEMP_LOCATION" ]; then
        exec_args="$exec_args --tempLocation=$DATAFLOW_TEMP_LOCATION"
    fi

    if [ -n "$DATAFLOW_STAGING_LOCATION" ]; then
        exec_args="$exec_args --stagingLocation=$DATAFLOW_STAGING_LOCATION"
    fi

    if [ -n "$DATAFLOW_NUM_WORKERS" ]; then
        exec_args="$exec_args --numWorkers=$DATAFLOW_NUM_WORKERS"
    fi

    if [ -n "$JOB_NAME" ]; then
        exec_args="$exec_args --jobName=$JOB_NAME"
    fi

    # There are other global options that can't be set through environment
    # variables right now. If we find a need to set these, we need to add
    # code here. The options that can't be defined include:
    #   - filesToStage
    #   - diskSizeGb
    #   - network
    #   - workerMachineType

    echo $exec_args
}

run_classifier_data_transfer_pipeline() {

    local segment_table=$BIGQUERY_DATASET.user_segment
    local diff_table=$BIGQUERY_DATASET.diff_classification
    # Create new Classification table name by datetime
    local new_classification_table=$BIGQUERY_DATASET.$(date -u +%Y%m%d_%H%M%S)_classification
    # Load last Classification table name from DataStore
    local last_classification_table_name=$(ds_util.py get --key=$DATASTORE_LAST_PROC_KEY --namespace=$DATASTORE_NAMESPACE --kind=$DATASTORE_KIND --prop=$DATASTORE_LAST_TABLE_PROP)
    local last_classification_table=$BIGQUERY_DATASET.$last_classification_table_name

    # Use BlockingDataflowPipelineRunner by default so that the we wait for the
    # launched job to finish. This will help prevent us from running the same
    # job twice concurrently.
    DATAFLOW_RUNNER=${DATAFLOW_RUNNER:-BlockingDataflowPipelineRunner}
    DATAFLOW_STREAMING=${DATAFLOW_STREAMING:-false}

    if [ -z "$BIGQUERY_DATASET" -o -z "$DATASTORE_NAMESPACE" -o -z "$INPUT_FILES" ]; then
        echo "Missing required environment variable: Cannot start classifier data transfer pipeline" >&2
        echo "  BIGQUERY_DATASET:      $BIGQUERY_DATASET" >&2
        echo "  DATASTORE_NAMESPACE:   $DATASTORE_NAMESPACE" >&2
        echo "  INPUT_FILES:           $INPUT_FILES" >&2
        exit 1
    fi

    # load old hash value from DataStore
    old_hash=$(ds_util.py get --key=$DATASTORE_LAST_PROC_KEY --namespace=$DATASTORE_NAMESPACE --kind=$DATASTORE_KIND --prop=$DATASTORE_LAST_HASH_PROP)
    # INPUT_FILES is a comma separated list of patterns. Replace the comma
    # with a space.
    new_hash=$(bucket_hash.py ${INPUT_FILES//,/ })

    # Setting the environment variable `SKIP_INPUT_FILES_PRECHECK` to "true"
    # will cause the pre-check to be skipped. Any other value (or not set at
    # all) will cause the pre-check to be performed.
    if [[ ( "$SKIP_INPUT_FILE_PRECHECK" == "true" ) || ( "$new_hash" != "$old_hash" ) ]]; then

        #
        # Step 1: Load segment csv files from GCS to BigQuery segment table
        # 
        echo "Step 1: Load segment csv files from GCS to BigQuery segment table"

        bq rm -f $segment_table
        bq mk --schema user_id:string,class:string -t $segment_table

        local files_array=${INPUT_FILES//,/ }
        for segment_file in ${files_array[@]}; do
            bq load $segment_table $segment_file
        done


        #
        # Step 2: Create new classification table
        #
        echo "Step 2: Create new classification table"

        bq query --use-legacy-sql=False --distination-table=$new_classification_table \
        "SELECT user_id, ARRAY_AGG(class) AS classes FROM `$segment_table` GROUP BY user_id"


        #
        # Step 3: Create a diff table for new_classification and last_classification
        #
        echo "Step 3: Create a diff table for new_classification and last_classification"

        # If there is no table processed last, new_classification table is outputted as it is
        if [ $last_classification_table_name ]; then
            bq query --use-legacy-sql=False --distination-table=$diff_table \
            "CREATE TEMPORARY FUNCTION ARRAY_SORT(arr ARRAY<STRING>) \
            RETURNS ARRAY<STRING> AS (( \
                SELECT ARRAY_AGG(x) FROM( \
                SELECT x FROM UNNEST(arr) AS x ORDER BY x \
                ) \
            )); \
            \
            SELECT \
                `$new_classification_table`.user_id, \
                `$last_classification_table`.ussr_id as old_user_id, \
                `$new_classification_table`.classes as new_classes, \
                `$last_classification_table`.classes as old_classes \
            FROM `$last_classification_table` \
                FULL OUTER JOIN `$new_classification_table` ON `$last_classification_table`.user_id = `$new_classification_table`.user_id \
            WHERE \
                ARRAY_TO_STRING(ARRAY_SORT(`$last_classification_table`.classes),' ') != ARRAY_TO_STRING(ARRAY_SORT(`$new_classification_table`.classes),' ') OR \
                ARRAY_LENGTH(`$last_classification_table`.classes) = 0; \ 
            "
        else
            bq query --use-legacy-sql=False --distination-table=$diff_table \
            "SELECT \
                `$new_classification_table`.user_id, \
                null as old_user_id, \
                `$new_classification_table`.classes as new_classes, \
                [] as old_classes \
            FROM `$new_classification_table`; \ 
            "
        fi


        #
        # Step 4: Start the DataFlow operation to synchronize BigQuery table and DataStore
        #
        echo "Step 4: Start the DataFlow operation to synchronize BigQuery table and DataStore"

        local exec_args=$(build_dataflow_exec_args)
        exec_args="$exec_args --input $diff_table --namespace=$DATASTORE_NAMESPACE"
        python update_classification.py $exec_args


        #
        # Step 5: Save the segment files hash
        #
        echo "Step 5: Update the segment files hash"

        ds_util.py set --key=$DATASTORE_LAST_PROC_KEY --namespace=$DATASTORE_NAMESPACE --kind=$DATASTORE_KIND --prop=$DATASTORE_LAST_HASH_PROP --value="$new_hash"


        #
        # Step 6: Update current classification table name
        #
        echo "Step 6: Update current classification table name"

        ds_util.py set --key=$DATASTORE_LAST_PROC_KEY --namespace=$DATASTORE_NAMESPACE --kind=$DATASTORE_KIND --prop=$DATASTORE_LAST_TABLE_PROP --value=$new_classification_table


        #
        # Step 7: delete unnecessary BigQuery tables
        #
        echo "Step 7: delete unnecessary BigQuery tables"

        bq rm -f $segment_table
        bq rm -f $diff_table
        if [ $last_classification_table ]; then
            bq rm -f $last_classification_table
        fi

    else
        echo "Skipping pipeline run, because it looks like nothing has changed"
    fi
}

case "$1" in
    run_classifier_data_transfer_pipeline)
        run_classifier_data_transfer_pipeline
        ;;

    help)
        echo "Usage:
        docker run \\
            -v ${HOME}/.config/gcloud/application_default_credentials.json:/var/credentials.json \\
            -e GOOGLE_APPLICATION_CREDENTIALS=/var/credentials.json \\
            -v /var/opt/ncd-pipeline:/var/opt/ncd-pipeline \\
            -e GOOGLE_PROJECT_ID=\"NameOfProject\" \\
            -e DATAFLOW_TEMP_LOCATION=gs://bucketName \\
            -e INPUT_FILES=gs://bucketName/inputFolder/*.txt,gs://bucketName/inputFolder2/*.gz \\
            -e BIGQUERY_DATASET=bq_dataset \\
            -e DATASTORE_NAMESPACE=namespace \\
            ncd-pipeline run_classifier_data_transfer_pipeline"
        ;;

    *)
        exec "$@"
esac