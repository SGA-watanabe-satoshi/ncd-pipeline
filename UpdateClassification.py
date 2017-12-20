"""A update classification datastore workflow."""

from __future__ import absolute_import

import argparse
import logging

import apache_beam as beam
from google.cloud import datastore
from apache_beam.metrics.metric import MetricsFilter
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.options.pipeline_options import SetupOptions
from datetime import datetime

logger = logging.getLogger(__name__)

class ClassificationUpdateDoFn(beam.DoFn):
    def __init__(self,namespace,kind):
        self._kind = kind
        self._namespace = namespace

    def start_bundle(self):
        self._client = datastore.Client(namespace=self._namespace)

    def process(self, element):
        """update or delete datastore entity"""
        logger.debug(element)

        # insert or update
        if element.get('user_id') is not None:
            key = self._client.key(self._kind, element.get('user_id'))
            entity = datastore.Entity(key)
            entity.update({
                'user_id': element.get('user_id'),
                'classes': element.get('new_classes'),
                'insert_time': datetime.now()
            })
            self._client.put(entity)


def run(argv=None):
    """Main entry point; defines and runs the update classification pipeline."""
    parser = argparse.ArgumentParser()
    # Target BigQuery table
    parser.add_argument('--input',
                        dest='input',
                        required=True,
                        help='Input BigQuery table to process specified as: '
                             'PROJECT:DATASET.TABLE or DATASET.TABLE.')
    # Target DataStore
    parser.add_argument('--output',
                        dest='output',
                        required=True,
                        help='Output destination DataStore')

    known_args, pipeline_args = parser.parse_known_args(argv)
    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(SetupOptions).save_main_session = True

    namespace = known_args.output.split(':')[0]
    kind = known_args.output.split(':')[1]

    p = beam.Pipeline(options=pipeline_options)

    ( p | 'read' >> beam.io.Read(beam.io.BigQuerySource(query="SELECT * FROM {table};".format(table=known_args.input), use_standard_sql=True))
        | 'update or delete datastore' >> beam.ParDo(ClassificationUpdateDoFn(namespace, kind)))
 
    p.run().wait_until_finish()


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.DEBUG)
    run()