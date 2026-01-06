#!/bin/bash

echo 'starting api at :5001'
cd /var/opt/leafapi/api/API
dotnet run &
echo 'api started...'

echo 'starting frontend at :3000'
cd /app/ui-client
npm start &
echo 'frontend started...'

wait