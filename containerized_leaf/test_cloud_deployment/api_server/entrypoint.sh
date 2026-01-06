#!/bin/bash

echo 'starting api at :5001'
cd /app/API
dotnet run &
echo 'api started...'

# If custom-compiling the api version you'll need this block instead:

# echo 'starting api at :5001'
# cd /var/opt/leafapi/api/API
# dotnet run &
# echo 'api started...'

wait
