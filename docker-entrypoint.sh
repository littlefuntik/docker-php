#!/usr/bin/env sh

echo ""

echo "File: /docker-entrypoint.sh"
cat /docker-entrypoint.sh

echo ""
echo "$@"

#echo ""
#composer install && php init --env=Dev --overwrite=All && php yii migrate --interactive=0
##su -s /bin/sh - www-data -c "cd $PWD && composer install && php init --env=Dev --overwrite=All && php yii migrate --interactive=0"
#for fn in $(find -user root); do chown -v www-data:www-data $fn; done
#chown -vR www-data:www-data rest/web/assets rest/runtime common/runtime

echo ""
exec "$@"
