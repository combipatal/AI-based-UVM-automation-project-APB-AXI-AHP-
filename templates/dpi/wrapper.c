#include <Python.h>
#include <stdio.h>
#include "svdpi.h"

// Python Module and Function References
static PyObject *pModule = NULL;

// Initialize Python Interpreter and Load Module
void dpi_python_init() {
    if (pModule != NULL) return; // Already initialized

    Py_Initialize();
    
    // Add current directory to sys.path
    PyRun_SimpleString("import sys");
    PyRun_SimpleString("sys.path.append('.')"); 
    PyRun_SimpleString("sys.path.append('./model')"); // Assuming model is in ./model

    pModule = PyImport_ImportModule("{{ model_module_name }}");
    
    if (pModule == NULL) {
        PyErr_Print();
        fprintf(stderr, "[DPI-C] Error: Failed to import python module '{{ model_module_name }}'\n");
    } else {
        printf("[DPI-C] Python module '{{ model_module_name }}' loaded successfully.\n");
    }
}

// Function to call Python 'dpi_mem_write'
// SV signature: import "DPI-C" context function void dpi_mem_write(int addr, int data);
void dpi_mem_write(int addr, int data) {
    if (pModule == NULL) dpi_python_init();

    if (pModule != NULL) {
        PyObject *pFunc = PyObject_GetAttrString(pModule, "dpi_mem_write");
        if (pFunc && PyCallable_Check(pFunc)) {
            PyObject *pArgs = PyTuple_New(2);
            PyTuple_SetItem(pArgs, 0, PyLong_FromLong(addr));
            PyTuple_SetItem(pArgs, 1, PyLong_FromLong(data));
            
            PyObject *pValue = PyObject_CallObject(pFunc, pArgs);
            if (pValue != NULL) {
                Py_DECREF(pValue);
            } else {
                PyErr_Print();
            }
            Py_DECREF(pArgs);
            Py_DECREF(pFunc);
        } else {
            if (PyErr_Occurred()) PyErr_Print();
            fprintf(stderr, "[DPI-C] Error: Cannot find function 'dpi_mem_write'\n");
        }
    }
}

// Function to call Python 'dpi_mem_read'
// SV signature: import "DPI-C" context function int dpi_mem_read(int addr);
int dpi_mem_read(int addr) {
    int result = 0;
    if (pModule == NULL) dpi_python_init();

    if (pModule != NULL) {
        PyObject *pFunc = PyObject_GetAttrString(pModule, "dpi_mem_read");
        if (pFunc && PyCallable_Check(pFunc)) {
            PyObject *pArgs = PyTuple_New(1);
            PyTuple_SetItem(pArgs, 0, PyLong_FromLong(addr));
            
            PyObject *pValue = PyObject_CallObject(pFunc, pArgs);
            if (pValue != NULL) {
                result = (int)PyLong_AsLong(pValue);
                Py_DECREF(pValue);
            } else {
                PyErr_Print();
            }
            Py_DECREF(pArgs);
            Py_DECREF(pFunc);
        } else {
            if (PyErr_Occurred()) PyErr_Print();
            fprintf(stderr, "[DPI-C] Error: Cannot find function 'dpi_mem_read'\n");
        }
    }
    return result;
}

// Clean up (Optional, usually simulation ends abruptly)
void dpi_python_finalize() {
    Py_Finalize();
}
