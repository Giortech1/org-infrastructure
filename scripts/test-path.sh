#!/bin/bash
echo "PATH in script: $PATH"
echo "Which gcloud: $(which gcloud)"
echo "Testing gcloud version:"
gcloud version --quiet
