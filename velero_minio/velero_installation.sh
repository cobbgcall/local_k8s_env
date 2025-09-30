#!/bin/bash
velero install --provider aws --plugins velero/velero-plugin-for-aws:1.13 --bucket minio \
--secret-file ./credentials-velero --use-volume-snapshots=false --backup-location-config \ 
region=minio,s3ForcePathStyle="true",s3Url=http://minio.velero.svc:9000