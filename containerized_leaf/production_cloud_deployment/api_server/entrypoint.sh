#!/bin/bash

echo 'starting api at :5001'
cd /var/opt/leafapi/api/API
dotnet run &
echo 'api started...'

wait
