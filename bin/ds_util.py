#!/usr/bin/env python
# -*- coding: utf-8 -*-
import argparse
import sys
import logging
from google.cloud import datastore
from datetime import datetime

logger = logging.getLogger(__name__)

def get_entity_value(namespace, kind, key, prop):
    client = datastore.Client(namespace=namespace)
    target_key = client.key(kind,int(key) if key.isdigit() else key)
    entity = client.get(target_key)

    if entity:
        if entity.get(prop):
            print entity.get(prop)
        else:
            print ''
            logger.warning('The target value is not set.')
    else:
        raise Exception('The target key does not exist.')

def set_entity_value(namespace, kind, key, prop, value):
    client = datastore.Client(namespace=namespace)
    target_key = client.key(kind,int(key) if key.isdigit() else key)
    entity = datastore.Entity(target_key)
    entity.update({
        prop: unicode(value),
        'created' : datetime.now()
    })
    client.put(entity)

if __name__ == '__main__':
    logging.basicConfig()
    logging.getLogger().setLevel(logging.INFO)
    try:
        parser = argparse.ArgumentParser()
        parser.add_argument('cmd',
                            action='store',
                            nargs=None,
                            const=None,
                            default=None,
                            choices=['get','set'],
                            metavar=None,
                            help='datastore operation (get/set)')
        parser.add_argument('--key',
                            dest='key',
                            required=True,
                            help='Target entity key')
        parser.add_argument('--namespace',
                            dest='namespace',
                            required=True,
                            help='Target DataStore namespace')
        parser.add_argument('--kind',
                            dest='kind',
                            required=True,
                            help='target DataStore kind')
        parser.add_argument('--prop',
                            dest='prop',
                            required=True,
                            help='Target entity property')
        parser.add_argument('--value',
                            dest='value',
                            help='Target entity property')

        args = parser.parse_args()
        cmd = args.cmd

        namespace = args.namespace
        kind = args.kind
        key = args.key
        prop = args.prop
        value = args.value

        if cmd == 'get':
            get_entity_value(namespace,kind,key,prop)
        elif cmd == 'set':
            set_entity_value(namespace,kind,key,prop,value)
        else:
            sys.exit(-1)
    except Exception as e:
        logger.error(e)
        sys.exit(-1)