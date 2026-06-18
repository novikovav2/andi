# Andi

Rails-приложение для разделения расходов между участниками события.

## Требования

- Ruby 3.3.11
- PostgreSQL

## Запуск

```bash
bin/setup
bin/dev
```

## Деплой

Деплой web-ревизии в Yandex Cloud Serverless Containers:

```bash
./deploy.sh
```

Production-миграции сейчас выполняются отдельно вручную, не через `deploy.sh`.
