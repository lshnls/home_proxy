# Home Proxy - Безопасная система маршрутизации трафика

## Состав проекта

Проект состоит из конфигурационных файлов приложений для создания полнофункциональной проксирующей системы:

- **Unbound** - DNS over TLS - защищенный DNS резолюция
- **iptables** — перехват TCP-трафика на портах 80 и 443 и перенаправление на прокси
- **Squid** — прозрачный прокси, фильтрация и выборочная маршрутизация
- **Privoxy** — преобразование HTTP(S)-трафика в SOCKS
- **Tor** — анонимизация и выход в интернет через Tor-сеть
- **obfs4** — транспортный плагин - кодирование Tor-трафика под случайный шум
- **snowflake** — транспортный плагин - обход блокировок через WebRTC
- **webtunnel** — транспортный плагин - маскировка трафика под HTTPS


## Быстрый старт

### Минимум команд для запуска

```bash
cd /home/lshnls/git/home_proxy
docker-compose up -d
make test-all
```

### Проверить работу

```bash
# DNS
dig @127.0.0.1 google.com

# Tor SOCKS
curl -x socks5://127.0.0.1:9050 https://api.ipify.org?format=json

# HTTP Прокси (Privoxy)
curl -x http://127.0.0.1:8118 https://api.ipify.org?format=json

# HTTP Прокси (Squid)
curl --proxy http://localhost:3128 https://check.torproject.org/api/ip
```

## Основные команды

```bash
# Запуск всех сервисов
docker-compose up -d

# Останов
docker-compose down

# Статус контейнеров
docker-compose ps

# Просмотр логов
docker-compose logs -f

# Перезагрузка
docker-compose restart

# Проверка всех сервисов
make test-all
```

## Сервисы и их порты

| Сервис | Порт | Назначение |
|--------|------|-----------|
| Unbound | 53/TCP/UDP | DNS over TLS |
| Tor | 9050/TCP | SOCKS5 прокси |
| Privoxy | 8118/TCP | HTTP прокси → Tor |
| Squid | 3128/TCP | Прозрачный HTTP прокси |

## Безопасность

✅ DNS резолюция через TLS  
✅ Трафик через Tor для анонимности  
✅ Фильтрация рекламы и трекеров  
✅ Прозрачное HTTPS перенаправление  
✅ Локальные Docker сети  
✅ Контейнеры без лишних привилегий  
✅ Поддержка obfs4, snowflake и WebTunnel для скрытия Tor-трафика

## Документация

[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - **Архитектура и структура**

## Примеры использования

### Использование DNS (Unbound)
```bash
dig @127.0.0.1 google.com
nslookup example.com 127.0.0.1
```

### Анонимный доступ через Tor
```bash
curl -x socks5://127.0.0.1:9050 https://api.ipify.org?format=json
```

### Через фильтрующий прокси
```bash
curl -x http://127.0.0.1:8118 https://api.ipify.org?format=json
```

### Через локальный прокси
```bash
curl -x http://127.0.0.1:3128 https://api.ipify.org?format=json
```

## Требования

- Docker >= 20.10
- Docker Compose >= 2.0
- Linux (для iptables)
- минимум 500 MB RAM
- 2-3 GB дискового пространства

## Используемые образы

- **mvance/unbound:latest** - Unbound DNS
- **osminogin/tor-simple:latest** - Tor
- **ghcr.io/binhex/arch-privoxy:latest** - Privoxy
- **ubuntu/squid:latest** - Squid

## Типичные сценарии использования

### Сценарий 1: Безопасный домашний интернет
```bash
docker-compose up -d
# Настроить iptables для прозрачного прокси
sudo bash scripts/setup-iptables.sh
```

### Сценарий 2: Анонимный доступ
```bash
# Используйте Tor SOCKS
curl -x socks5://127.0.0.1:9050 https://api.ipify.org
```

### Сценарий 3: Фильтрация при сохранении приватности
```bash
# Используйте Privoxy (с блокировкой рекламы) + Tor
curl -x http://127.0.0.1:8118 https://api.ipify.org
```

## FAQ

**Q: Будет ли медленнее интернет?**  
A: Да, немного медленнее, но намного безопаснее

**Q: Можно ли использовать без Tor?**  
A: Да, просто отредактируйте docker-compose.yml

**Q: Как изменить конфигурацию?**  
A: Отредактируйте файлы в `config/` и перезагрузитесь

**Q: Как изменить права на `./tor/data`, чтобы и контейнер, и пользователь проекта имели доступ?**  
A: Перед запуском задайте GID пользователя проекта и перезапустите Tor:
```bash
export PROJECT_GID=$(id -g)
docker-compose up -d --build tor
```
Контейнер при старте выставит владельца `tor`, группу `${PROJECT_GID}` и права `2770` для каталогов / `660` для файлов в `./tor/data`.

## Troubleshooting

```bash
# Проверить логи
docker-compose logs SERVICE_NAME

# Проверить здоровье всех сервисов
bash scripts/health-check.sh

# Перезагрузить контейнер
docker-compose restart SERVICE_NAME
```

## Лицензия

MIT License

## Поддержка

Создавайте issues для вопросов и проблем.

---

**Архитектура:** [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

## Ошибка `MOZILLA_PKIX_ERROR_SELF_SIGNED_CERT` при прозрачном HTTPS

Эта ошибка появляется, когда браузер получает сертификат, подписанный локальным CA Squid, но не доверяет этому CA.

Что нужно сделать:

1. Запустить/пересобрать контейнер Squid (сертификат создается в `squid/ssl/squidCA.crt`):
   ```bash
   docker-compose up -d --build squid
   ```
2. Установить `squid/ssl/squidCA.crt` как доверенный корневой сертификат в ОС/браузере (для Firefox — в его хранилище сертификатов или через enterprise policy).
3. Перезапустить браузер.

Важно: в проекте добавлен bind-mount `./squid/ssl:/etc/squid/ssl`, поэтому CA теперь не генерируется заново при каждом рестарте контейнера. Это позволяет один раз импортировать сертификат и не получать ошибку снова после перезапуска.
