#!/usr/bin/env python
#############
# dirty python tricks to import any file as a module without py ext
from importlib.machinery import SourceFileLoader

def src_file_(name, where=None):
    if where is None:
        path = name
    else:
        path = f"{where}/{name}"
    return SourceFileLoader(name, path).load_module()