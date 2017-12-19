# -*- coding: utf-8 -*-
import json
import sys
from google.cloud import datastore
from datetime import datetime

namespace = 'watanabe'
kind = 'Sample'
target_key = '5695159920492544'
target_property = 'last_proc_table'

client = datastore.Client(namespace=namespace)

def get_last_table():
    key = client.key(kind,int(target_key))
    entity = client.get(key)

    if entity.get(target_property):
        print entity.get(target_property)

def set_last_table(tablename):
    key = client.key(kind,int(target_key))
    entity = datastore.Entity(key)
    entity.update({
        target_property: unicode(tablename),
        'created' : datetime.now()
    })
    client.put(entity)

if __name__ == '__main__':
    args = sys.argv
    if len(args) == 2 and args[1] == 'get':
        get_last_table()
    elif len(args) == 3 and args[1] == 'set':
        set_last_table(args[2])
            