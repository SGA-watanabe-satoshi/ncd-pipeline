# New Classification Data Pipeline
Cloud Dataflow pipeline to copy classification files from Cloud Storage to DataStore with BigQuery

## Build
To build the docker image, use the supplied script:
```
[~]$ ./docker_build.sh
```
## Run

The following command will run the docker container

```
[~]$ docker run ${DOCKER_REPO}ncd-pipeline run_classifier_data_transfer_pipeline
```

There are number of configuration items that will need to be specified in
order to run successfully. For example:

```
docker run \
    -v /var/opt/ncd-pipeline:/var/opt/ncd-pipeline \
    -e GOOGLE_PROJECT_ID="ace-ripsaw-671" \
    -e DATAFLOW_TEMP_LOCATION=gs://watanabe-misc \
    -e INPUT_FILES=gs://classification-data/user_classification/*/*.gz,gs://classification-data/user_classification-2/*/*.txt \
    -e BIGQUERY_DATASET=satoshi_dataset \
    -e DATASTORE_NAMESPACE=watanabe \
    ${DOCKER_REPO}ncd-pipeline run_classifier_data_transfer_pipeline
```

## Configuration

Some configuration options map directly to Cloud Dataflow pipeline execution
parameters. When this is the case, see the [Cloud Dataflow documentation][pipeline-options]
for a complete description.

Configurable environment variables:

* `BIGQUERY_DATASET` - [Required] Specify the BigQuery data set for intermediate
  processing. The final processed result is retained in this data set and used 
  for the next operation.
* `DATASTORE_NAMESPACE` - [Required] Cloud Datastore namespace to used for
  storing classification data.
* `DATAFLOW_NUM_WORKERS` - The number of Google Compute Engine instances to
  use to run cd-pipeline. Maps to the Cloud Dataflow pipeline execution
  parameter `--numWorkers`.
* `DATAFLOW_RUNNER` - The PipelineRunner to use. Maps to the Cloud Dataflow
  pipeline execution parameter `--runner`. [Default - `BlockingDataflowPipelineRunner`]
* `DATAFLOW_STAGING_LOCATION` - Google Cloud Storage path for staging local
  files. Maps to the Cloud Dataflow pipeline execution parameter
  `--stagingLocation`. You must specify at least one of `DATAFLOW_TEMP_LOCATION`
  or `DATAFLOW_STAGING_LOCATION`.
* `DATAFLOW_TEMP_LOCATION` - Google Cloud Storage path for temporary files.
  Maps to the Cloud Dataflow pipeline execution parameter `--tempLocation`.
  You must specify at least one of `DATAFLOW_TEMP_LOCATION` or
  `DATAFLOW_STAGING_LOCATION`.
* `GOOGLE_PROJECT_ID` - [Required] The project ID for your Google Cloud Project.
  Maps to the Cloud Dataflow pipeline execution parameter `--project`.
* `INPUT_FILES` - [Required] File name or pattern of the files to read. Standard
  Java Filesystem glob patterns ("*", "?", "[..]") are supported.
* `JOB_NAME` - Dataflow job name. Must be unique. Maps to the Cloud Dataflow
  pipeline execution parameter `--jobName`.
* `SKIP_INPUT_FILE_PRECHECK` - Flag to turn off pre-check of `$INPUT_FILES`.
  Setting to the string "true" will cause the pre-check to be skipped. Any
  other value (or not set at all) will cause the pre-check to be performed.