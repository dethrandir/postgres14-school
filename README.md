# PostgreSQL 14.24 + pgAdmin

macOS ve Linux için tek komut:

```bash
curl -fsSL https://raw.githubusercontent.com/dethrandir/postgres14-school/main/install.sh | sh
```

## Gereksinimler

- macOS veya Linux
- Docker

Docker kurulu değilse kurulum scripti gerekli yönlendirmeyi gösterir.

## PostgreSQL

- Host: `localhost`
- Port: `5432`
- Database: `postgres`
- Username: `postgres`
- Password: `postgres`

Bağlantı URL'si:

```text
postgresql://postgres:postgres@localhost:5432/postgres
```

## pgAdmin

Tarayıcıdan aç:

```text
http://localhost:5050
```

Giriş bilgileri:

- Email: `admin@localhost.com`
- Password: `admin`

pgAdmin içerisinden PostgreSQL sunucusuna bağlanırken:

- Host: `postgres`
- Port: `5432`
- Database: `postgres`
- Username: `postgres`
- Password: `postgres`

> `localhost` yerine `postgres` kullanılmasının nedeni pgAdmin ve PostgreSQL'in aynı Docker ağı içerisinde çalışmasıdır.

## Durdurma

```bash
cd ~/postgres14-school
docker compose -f compose.yml down
```

## Tekrar Başlatma

```bash
cd ~/postgres14-school
docker compose -f compose.yml up -d
```

## Verileri Tamamen Silme

Aşağıdaki komut PostgreSQL ve pgAdmin volume'larını da siler:

```bash
cd ~/postgres14-school
docker compose -f compose.yml down -v
```

## Kurulum Dizini

Script gerekli dosyaları otomatik olarak şu dizine oluşturur:

```text
~/postgres14-school
```

Oluşturulan dosyalar:

```text
postgres14-school/
├── compose.yml
├── .env
└── servers.json
```

## Not

Bu yapılandırma yerel geliştirme ve eğitim amacıyla hazırlanmıştır.

Production ortamlarında varsayılan kullanıcı adı ve şifreleri kullanmayın.

Kolay gelsin kankalarim benim 😇
