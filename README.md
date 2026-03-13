# для проверки
``` bash

```

# Home Proxy - Безопасная система маршрутизации трафика

## 📋 Состав проекта

Проект состоит из конфигурационных файлов приложений для создания полнофункциональной проксирующей системы:

- **Unbound** - DNS over TLS - защищенный DNS резолюция
- **iptables** — перехват TCP-трафика на портах 80 и 443 и перенаправление на прокси
- **Squid** — прозрачный прокси, фильтрация и выборочная маршрутизация
- **Privoxy** — преобразование HTTP(S)-трафика в SOCKS
- **Tor** — анонимизация и выход в интернет через Tor-сеть
- **obfs4** — транспортный плагин - кодирование Tor-трафика под случайный шум
- **WebTunnel** (опционально) — транспортный плагин - маскировка Tor под обычный HTTPS-трафик (HTTP/2, WebSocket)

## 🚀 Быстрый старт

### 1️⃣ Минимум команд для запуска

```bash
cd /home/lshnls/git/home_proxy
docker-compose up -d
make test-all
```

### 2️⃣ Проверить работу

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

## 📁 Структура проекта

```
home_proxy/
├── docker-compose.yml       # Полная конфигурация всех сервисов
├── docker-compose.quick.yml # Минимальная конфигурация
├── Makefile                 # Удобные команды управления
├── config/                  # Конфигурационные файлы сервисов
│   ├── unbound.conf        # DNS конфигурация
│   ├── torrc               # Tor конфигурация
│   ├── squid.conf          # Squid конфигурация
│   └── privoxy/            # Privoxy конфигурация
├── scripts/                # Утилиты
│   ├── setup-iptables.sh  # Настройка перехвата трафика
│   └── health-check.sh    # Проверка здоровья сервисов
└── docs/                   # Документация
    ├── QUICKSTART.md       # Быстрый старт (5 минут)
    ├── SETUP.md           # Полная документация
    └── PROJECT_STRUCTURE.md # Архитектура проекта
```

## 🔧 Основные команды

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

## 📊 Сервисы и их порты

| Сервис | Порт | Назначение |
|--------|------|-----------|
| Unbound | 53/TCP/UDP | DNS over TLS |
| Tor | 9050/TCP | SOCKS5 прокси |
| Privoxy | 8118/TCP | HTTP прокси → Tor |
| Squid | 3128/TCP | Прозрачный HTTP прокси |

## 🛡️ Безопасность

✅ DNS резолюция через TLS  
✅ Трафик через Tor для анонимности  
✅ Фильтрация рекламы и трекеров  
✅ Прозрачное HTTPS перенаправление  
✅ Локальные Docker сети  
✅ Контейнеры без лишних привилегий  
✅ Поддержка obfs4 и WebTunnel для скрытия Tor-трафика  

## 📚 Документация

- [QUICKSTART.md](QUICKSTART.md) - **За 5 минут до работающей системы**
- [SETUP.md](SETUP.md) - **Полная инструкция и конфигурация**
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - **Архитектура и структура**

## ⚡ Примеры использования

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

## 🔍 Требования

- Docker >= 20.10
- Docker Compose >= 2.0
- Linux (для iptables)
- минимум 500 MB RAM
- 2-3 GB дискового пространства

## 📦 Используемые образы

- **mvance/unbound:latest** - Unbound DNS
- **osminogin/tor-simple:latest** - Tor
- **ghcr.io/binhex/arch-privoxy:latest** - Privoxy
- **ubuntu/squid:latest** - Squid

## 🎯 Типичные сценарии использования

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

## ❓ FAQ

**Q: Как быстро запустить?**  
A: Прочитайте [QUICKSTART.md](QUICKSTART.md)

**Q: Будет ли медленнее интернет?**  
A: Да, немного медленнее, но намного безопаснее

**Q: Можно ли использовать без Tor?**  
A: Да, просто отредактируйте docker-compose.yml

**Q: Как изменить конфигурацию?**  
A: Отредактируйте файлы в `config/` и перезагрузитесь

## 🐛 Troubleshooting

```bash
# Проверить логи
docker-compose logs SERVICE_NAME

# Проверить здоровье всех сервисов
bash scripts/health-check.sh

# Перезагрузить контейнер
docker-compose restart SERVICE_NAME
```

## 📄 Лицензия

MIT License

## 🙋 Поддержка

Создавайте issues для вопросов и проблем.

---

**Начните за 5 минут:** [QUICKSTART.md](QUICKSTART.md) | **Полная инструкция:** [SETUP.md](SETUP.md) | **Архитектура:** [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)
