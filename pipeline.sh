#!/bin/bash

set -eo pipefail
set -x

env=watanabe_dataset
segment_table=$env.user_segment
# Create new Classification table name by datetime
new_classification_table=$(date -u +%Y%m%d_%H%M%S)_classification
# Load Old Classification table name from DataStore
old_classification_table=$(python DatastoreUtil.py get)
diff_table="diff_classification"

declare -a segment_files=(
    "gs://prod-classification-data/*",
    "gs://prod-classification-data-2/*",
    "gs://prod-classification-data-4/*",
    "gs://prod-classification-data-data-on-demand/*"
)

#
# Step 1 Load segment csv files from GCS to BigQuery segment table
# 
bq rm -f $segment_table
bq mk --schema user_id:string,class:string -t $segment_table

for segment_file in ${segment_files[@]}; do
    bq load $segment_table $segment_file
done

#
# Step 2 Create new classification table
#
bq query --use-legacy-sql=False --distination-table=$new_classification_table \
"SELECT user_id, ARRAY_AGG(class) AS classes FROM `$segment_table` GROUP BY user_id"

#
# Step 3 Create a diff table for new_classification and old_classification
#
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
  `$old_classification_table`.ussr_id as old_user_id, \
  `$new_classification_table`.classes as new_classes, \
  `$old_classification_table`.classes as old_classes \
FROM `$old_classification_table` \
FULL OUTER JOIN `$new_classification_table` ON `$old_classification_table`.user_id = `$new_classification_table`.user_id \
WHERE \
  ARRAY_TO_STRING(ARRAY_SORT(`$old_classification_table`.classes),' ') != ARRAY_TO_STRING(ARRAY_SORT(`$new_classification_table`.classes),' ') OR \
  ARRAY_LENGTH(`$old_classification_table`.classes) = 0; \ 
"

#
# Step 4 Start DataFlow operation BigQuery(diff_table) to DataStore(user_classification)
#


#
# Step 5 Update current classification table name
#
python DatastoreUtil.py set $new_classification_table

#
# Step 6 delete unnecessary tables
#
bq rm -f $segment_table
bq rm -f $old_classification_table
bq rm -f $diff_table