# Home Proxy - Полная структура проекта

```
home_proxy/
├── README.md                          # Исходное описание проекта
├── SETUP.md                           # Полная инструкция по установке
├── QUICKSTART.md                      # Быстрый старт за 5 минут
├── docker-compose.yml                 # Полная конфигурация (рекомендуется)
├── docker-compose.quick.yml           # Минимальная конфигурация
├── Makefile                           # Команды управления
├── .env.example                       # Пример переменных окружения
├── .gitignore                         # Исключения для Git
│
├── config/                            # Конфигурационные файлы
│   ├── unbound.conf                   # DNS over TLS конфигурация
│   ├── torrc                          # Tor конфигурация
│   ├── squid.conf                     # Squid прокси конфигурация
│   └── privoxy/
│       ├── config                     # Privoxy основная конфигурация
│       └── user.action                # Privoxy пользовательские правила
│
├── scripts/                           # Утилиты и вспомогательные скрипты
│   ├── setup-iptables.sh              # Настройка перехвата трафика (root)
│   └── health-check.sh                # Проверка состояния всех сервисов
│
└── logs/                              # Директория для логов (создается Docker)
    └── (логи создаются автоматически)
```

## Быстрая справка

### Установка и запуск
```bash
cd /home/lshnls/git/home_proxy
docker-compose up -d
make test-all
```

### Управление
```bash
make up              # Запуск
make down            # Остановка
make ps              # Статус
make logs            # Логи
make restart         # Перезагрузка
```

### Сервисы и их порты
- **Unbound DNS**: 53/tcp, 53/udp (локально: 127.0.0.1:53)
- **Tor SOCKS5**: 9050/tcp (локально: 127.0.0.1:9050)
- **Privoxy HTTP**: 8118/tcp (локально: 127.0.0.1:8118)
- **Squid Proxy**: 3128/tcp (локально: 127.0.0.1:3128)

### Цепь обработки трафика
```
HTTP/HTTPS трафик
    ↓
Squid (прозрачный прокси, кеш, фильтрация)
    ↓
Privoxy (преобразование в SOCKS, блокировка рекламы)
    ↓
Tor (анонимизация, выход в интернет)
    ↓
DNS запросы через Unbound (TLS)
```

## Зависимости между сервисами

```
Host Network (iptables)
    ↓
Squid ← Privoxy ← Tor
    ↓
Unbound (DNS)
```

## Требования к системе
- Docker >= 20.10
- Docker Compose >= 2.0
- Linux (для iptables)
- Минимум 500 MB RAM
- 2-3 GB дискового пространства (кеш)

## Документация

- [QUICKSTART.md](QUICKSTART.md) - 5-минутный старт
- [SETUP.md](SETUP.md) - Полная документация
- Конфигурационные файлы содержат комментарии

## Поддерживаемые операции

### Docker Compose команды
```bash
docker-compose up -d              # Запуск
docker-compose down               # Остановка
docker-compose ps                 # Статус
docker-compose logs -f            # Логи
docker-compose restart            # Перезагрузка
docker-compose exec squid bash    # Shell в контейнер
```

### Make команды (см. Makefile)
```bash
make help          # Справка по командам
make up            # Запуск всех сервисов
make down          # Остановка
make logs          # Просмотр логов
make test-all      # Все тесты
make clean         # Полная очистка
make status        # Статус и использование памяти
```

## Расширение проекта

### Добавить новый фильтр Privoxy
Отредактируйте `config/privoxy/user.action` и добавьте:
```
{ +block{Custom block} }
example.com
bad-site.com
```

### Измениить DNS серверы
В `config/unbound.conf` отредактируйте `forward-zone`

### Изменить размер кеша Squid
В `config/squid.conf`:
```
cache_dir ufs /var/spool/squid 20000 16 256
```

## Troubleshooting

### DNS не работает
```bash
docker-compose logs unbound
dig @127.0.0.1 google.com
```

### Tor недоступен
```bash
docker-compose logs tor
curl -x socks5://127.0.0.1:9050 https://api.ipify.org
```

### Squid проблемы
```bash
docker-compose exec squid squid -k reconfigure
docker-compose logs squid
```

## Лог файлы

Логи хранятся в контейнерах:
```bash
docker-compose logs SERVICE_NAME

# Или внутри контейнера:
docker-compose exec SERVICE_NAME ls -la /var/log/
```

## Версии используемых образов

- **Unbound**: mvance/unbound:latest
- **Tor**: osminogin/tor-simple:latest
- **Privoxy**: ghcr.io/binhex/arch-privoxy:latest
- **Squid**: ubuntu/squid:latest

Обновление образов:
```bash
docker-compose pull
docker-compose up -d
```

## Архитектура

```
┌─────────────────────────────────────────────────────┐
│         Docker Network (proxy_network)               │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ Unbound  │  │  Privoxy │  │   Tor    │          │
│  │   DNS    │  │ (HTTP→   │  │ (SOCKS5) │          │
│  │   53     │  │  SOCKS5) │  │   9050   │          │
│  │          │  │   8118   │  │          │          │
│  └──────────┘  └──────────┘  └──────────┘          │
│                      ↑              ↑               │
│                      └──────┬───────┘               │
│                             │                      │
│                        ┌────▼─────┐                │
│                        │  Squid    │                │
│                        │  Proxy    │                │
│                        │   3128    │                │
│                        └───────────┘                │
│                                                     │
└─────────────────────────────────────────────────────┘
            ↑                              ↑
            │ DNS (127.0.0.1:53)          │
    ┌───────┴──────────────────────────────┘
    │ HTTP/HTTPS через iptables (опционально)
    │
  HOST
```

## FAQ

**Q: Зачем нужны все эти сервисы?**
A: Каждый выполняет свою функцию:
- Unbound: защищенный DNS через TLS
- Squid: кеш и маршрутизация трафика
- Privoxy: преобразование в SOCKS, фильтрация
- Tor: анонимизация

**Q: Буду ли я медленнее серфить?**
A: Немного медленнее из-за многих слоев обработки, но намного безопаснее.

**Q: Можно ли использовать без Tor?**
A: Да, просто используйте Squid + Unbound.

**Q: Как получить максимальную производительность?**
A: Используйте docker-compose.quick.yml и отключитененужные фильтры.

## Контрибьютирование

Если у вас есть улучшения для конфигурации, создавайте PR!

## Лицензия

MIT License

## Автор

Home Proxy Team
