# Лабораторная 1
## Задание
Настроить nginx по заданному тз:
1. Должен работать по https c сертификатом
2. Настроить принудительное перенаправление HTTP-запросов (порт 80) на HTTPS (порт 443) для обеспечения безопасного соединения.
3. Использовать alias для создания псевдонимов путей к файлам или каталогам на сервере.
4. Настроить виртуальные хосты для обслуживания нескольких доменных имен на одном сервере.

## Выполнение
Чтобы сильно не упрощать себе жизнь и для получения полезного опыта всю работу было решено выполнять на удалённом сервере. Для подключения к нему использовался ssh.<br>

Было решено начать с генерации сертификатов. Тут меня и ждала первая сложность. Я нашёл два варианта бесплатной генерации сертификатов: certbot и OpenSSL. Как оказалось первый требует наличие домена, а на сертификаты от второго браузер кричит и считает небезопасными. Делать нечего, да и давно уже было пора. Покупаем домен.<br>

Благо мой основной никнейм никому кроме меня в интернете не нужен и samsemrod.ru был свободен. Его за 179 рублей и возьмем. Ниже на фото пока что все созданные домены. Важно обратить внимание на поддомены blue и red. Они будут использоваться далее<br>
![image](https://github.com/user-attachments/assets/37113c26-2f17-48c8-adc3-f1e43ae15660) <br>

Далее на сервере в папке `var/www` были созданы две директории со страницами сайтов: `blue.samsemrod.ru` и `red.samsemrod.ru` соответственно <br>

В качестве пет-проектов были выбраны два достаточно простых сайта с двумя картинками на фоне. На одном сайте синяя картинка и надпись "Это синий сайт!", на другом красная с аналогичной надписью.<br>

Сначала я просто написал один заголовок и вставил картинку, но мои фронтендерские глаза стали немного кровоточить при виде такой "крутой" страницы, поэтому в итоге их код выглядел следующим образом <br>

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
    <div class="background-container">
        <div class="centered-text">Это красный сайт!</div>
    </div>
</body>
</html>
```
 
С такими стилями, соответственно <br>
```css
body, html {
            height: 100%;
            margin: 0;
            font-family: Arial, sans-serif;
        }

.background-container {
            background: url('redlenin.jpg') no-repeat center top fixed;
            background-size: cover;
            height: 100%;
            display: flex;
            justify-content: center;
            align-items: center;
        }

.centered-text {
            color: white;
            font-size: 48px;
            text-shadow: 6px 6px 16px rgba(0, 0, 0, 7);
            text-align: center;
        }
``` 
На результат посмотрим в конце <br>

Сейчас перейдём к nginx конфигурации. Она хранится в директории `/etc/nginx/sites-available`. И так как страниц у нас будет две, то и конфигураций тоже сделаем две (здесь показана только для красного сайта, но представьте ещё вторую ) <br>

```nginx
server {
    listen 80;
    server_name red.samsemrod.ru;
    return 301 https://$host:8443$request_uri;
}
server {
    listen 443 ssl;
    server_name red.samsemrod.ru;

    root /var/www/red.samsemrod.ru;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /images/ {
        alias /var/www/red.samsemrod.ru/;
    }
}
```

Разберёмся с этим кодом подробнее <br>

первый `server { listen 80; ... }` нужен для получения запросов извне и перенаправления их на https<br>
в нём прописан стандартный порт (80) и доменное имя (red.samsemrod.ru) и адрес куда отправить запрос<br>

во втором `server { listen 443 ssl; ... }` этот запрос и обрабатывается. именно здесь прописан путь до сайта, alias для доступа к картинке и тут же должно быть шифрование. Сейчас мы его и добавим. Для этого загружаем нужные компоненты <br>

`sudo apt install certbot python3-certbot-nginx` <br>
И создаём сертификаты 
```bash
sudo certbot --nginx -d red.samsemrod.ru
sudo certbot --nginx -d blue.samsemrod.ru
```
Проверить их можно по адресу `/etc/letsencrypt/live/`, ну и по новым строчкам в конфигурациях. По умолчанию они почему-то вставлялись в listen 80, само собой их нужно перенести на listen 443 ssl. Итоговая автоматически сгенерированная настройка шифрования в файле представляет 4 строчки <br>
```
ssl_certificate /etc/letsencrypt/live/red.samsemrod.ru/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/red.samsemrod.ru/privkey.pem;
include /etc/letsencrypt/options-ssl-nginx.conf;
ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
```

Дальше казалось бы всё готово и уже можно любоваться обещанным сайтом. К сожалению, тут меня поджидала вторая проблема. Стандартный порт 443 уже был занят службами, убивать которые я не мог. Надо объяснить, что для выполнения лабы использовался сервер, который также используется для своего VPN, который мы с другом сделали около двух лет назад, поэтому убийство какой-то службы было черевато поломками (и ударами по голове от друга). Было найдено компромиссное решение использовать нестандартный, но свободный порт. Я выбрал 8443, потому что нужно дописать всего одну цифру)<br>

В итоге код конфигурации после добавления сертификатов и замены порта принял вот такой вид

```nginx
server {
    listen 80;
    server_name red.samsemrod.ru;
    return 301 https://$host:8443$request_uri;
}

server {
    listen 8443 ssl;  # Используем порт 8443 для HTTPS
    server_name red.samsemrod.ru;

    ssl_certificate /etc/letsencrypt/live/red.samsemrod.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/red.samsemrod.ru/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /var/www/red.samsemrod.ru;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /images/ {
        alias /var/www/red.samsemrod.ru/;
    }
}
```

Для запуска проверки работоспособности нужно добавить ссылку на каждую конфигурацию в `/etc/nginx/sites-enabled/`

```bash
sudo ln -s /etc/nginx/sites-available/red.samsemrod.ru /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/blue.samsemrod.ru /etc/nginx/sites-enabled/
```
Проверить правильность конфигурации и, если проблем не найдено, перезагрузить nginx
```bash
sudo nginx -t
sudo systemctl reload nginx
```
Заходим на [red.samsemrod](https://red.samsemrod.ru:8443/) и [blue.samsemrod](https://blue.samsemrod.ru:8443/) и радуемся результату <br>

![image](https://github.com/user-attachments/assets/339afccc-5cae-47b9-8a60-512bca71f2f8)

![image](https://github.com/user-attachments/assets/6fb8c9cc-39a4-49e7-afd3-e65432ab77e9)

![image](https://github.com/user-attachments/assets/c156915e-c293-4d4e-98aa-acef82255c91)

Проверим работу alias, которые у нас настроены на отображение фоновыхъ картинок. Для этого просто пропишем после адреса сайта /images/vangog.jpg (для синего сайта) чтобы посмотреть на Звёздную ночь Винсента ван Гога и /images/redlenin.jpg (для красного сайта) чтобы посмотреть на Красного Ленина Энди Уорхола <br>

![image](https://github.com/user-attachments/assets/781a00f8-85ca-4e1f-8f0d-f6f9e6e3f3c3)

# Задание со звёздочкой
В данной лабораторной были проверены уязвимости конфигурации команды №5
# Выполнение 
## Проверка заголовков
Посмотрим на заголовки HTTP, которые можно прописать в конфиге nginx для лучшей безопасности. На свой сайтик, я (после просмотра проверки от коллег, конечно, я не такой умник) добавил три рекомендованных заголовка, поэтому будет с чем сравнить ответы
вот ответ проверяемого сайта <br>
![image](https://github.com/user-attachments/assets/d60c7613-1a5b-454f-9f09-c4b298b71d88) <br>
вот ответ моего сайта <br>
![image](https://github.com/user-attachments/assets/e3a62c11-2585-4cc2-8ff8-aefb6fef015d) <br>
Как несложно заметить на проверяемом сайте есть переадресация с HTTP на HTTPS и он поставлен на сервере Ubuntu, но заголовков безопасности нет, что может сделать сайт уязвимым для атак типа MITM (man in the middle), когда жулик использует некую прокладку между хорошим сайтом с HTTPS и плохим и ворует данные пользователей. Также можно обезопасить себя от XSS атак (пока неактуально так как полей ввода нету), и неправильной интерпретации файлов с разными типами и ещё нескольких уязвимостей.
Для самообороны стоит прописать эти загловки в конфигурации
```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self';";
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Content-Type-Options "nosniff";
add_header X-Frame-Options "DENY";
add_header X-XSS-Protection "1; mode=block";
``` 
## Перебор страниц с помощью ffuf
В этом пункте попробуем найти в сайте (а может и на самом сервере), что-нибудь что нам смотреть не положено. Для этого используем инструмент ffuf со словарём из SecLists. Для начала надо скачать собственно словарь путей (на самом деле достаточно только скачивания одного файла оттуда, но кто же знал что эта штука весит 3.5 гига):
```bash
git clone https://github.com/danielmiessler/SecLists.git
```
Для понимания в нём хранятся вот такого вида строчки <br>
![image](https://github.com/user-attachments/assets/5dd1b9a1-c1a6-4ec3-9bbc-a72d20b8c2d2) <br>
и так ещё 20476 раз... Поэтому если что-то потайное и есть, то мы это обязательно найдём!
После этого можно запустить проверку на скрытые директории по этому словарю.
```bash
ffuf -w ~/SecLists/Discovery/Web-Content/big.txt -u https://itmo-clouds-labs.ru/FUZZ -t 50 -mc 200,301,302
```
Результат <br>
![image](https://github.com/user-attachments/assets/8cd3d826-3872-4580-8137-10add4faa0d1) <br>
![image](https://github.com/user-attachments/assets/e90a98d9-b124-4755-b982-6e4bfb94175c) <br>
Эти ответы означают, что ничего потайного найти не удалось и при каждом запросе нам возвращалась та же самая страница.
Обидно. 
Но ожидаемо, так как location / {...}, который был использован в проверяемом конфиге, перекидывает абсолютно все запросы туда, куда показывает содержимое фигурных скобочек
## Проверка SSL/TLS
Здесь мы попробуем найти какие-нибудь уязвимости или устарелости в шифровании проверяемого сайта
Для этого используем nmap с скриптом, который покажет все шифры <br> 
![image](https://github.com/user-attachments/assets/7fe205a0-6c86-470a-a474-0386ab450198) <br>
Как можно заметить, здесь всё, в целом, хорошо. используются новые версии сертификатов, хорошая оценка шифров и нет компрессоров.
Единственное что приоритетными для сервера являются шифры клиента, это не совсем безопасно. Так как клиент может использовать устаревший шифр и злоумышленник может вклиниться между сервером и клиентом и перехватить данные, пользуясь устаревшими настройками. Для усиления защиты стоит поменять приоритеты

## Выводы
Проверка была проведена, найдено несколько небольших уязвимостей, которые решаются парой строчек в конфиге и консоли, но они есть. Также логично что уязвимостей немного, так как сайт мегапростой, даже проверку на XSS (Cross-site scripting) было бессмыслено проводить, потому что некуда эти ваши scripting вставлять, инпутов нет. Было обидно ничего не найти через ffuf, но потом подумал и понял, что это ожидаемо достаточно. Пока делал узнал чего-то нового про варианты взлома, про человека по середине вообще интересно было почитать потом на википедии
