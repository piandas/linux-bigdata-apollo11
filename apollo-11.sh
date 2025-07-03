#!/usr/bin/env bash

min=1
max=100

# calcula un número aleatorio entre $min y $max
numero=$(( RANDOM % (max - min + 1) + min ))

echo $numero