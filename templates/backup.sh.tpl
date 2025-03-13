#!/bin/bash

# Variables
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/app/backups"
DB_USER="${db_user}"
DB_NAME="${db_name}"
BACKUPS_TO_KEEP=${backups_to_keep}

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Log start of backup
echo "Starting database backup at $(date)"

# Backup the database
echo "Creating database dump..."
docker exec fisioapp-postgres pg_dump -U $DB_USER -d $DB_NAME > $BACKUP_DIR/fisioapp_$TIMESTAMP.sql

# Check if backup was successful
if [ $? -eq 0 ]; then
  echo "Database dump created successfully"
else
  echo "Error creating database dump"
  exit 1
fi

# Compress the backup
echo "Compressing backup file..."
gzip $BACKUP_DIR/fisioapp_$TIMESTAMP.sql

# Check if compression was successful
if [ $? -eq 0 ]; then
  echo "Backup compressed successfully"
else
  echo "Error compressing backup"
  exit 1
fi

# Keep only the most recent backups
echo "Cleaning up old backups, keeping the $BACKUPS_TO_KEEP most recent..."
ls -t $BACKUP_DIR/*.gz | tail -n +$((BACKUPS_TO_KEEP+1)) | xargs -r rm -f

# Log completion
echo "Backup completed at $(date)"
echo "Backup saved to $BACKUP_DIR/fisioapp_$TIMESTAMP.sql.gz"

# Output disk usage
echo "Current backup disk usage:"
du -sh $BACKUP_DIR