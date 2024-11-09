# Лабараторная 5 #
## Основное задание ##
В этом задание нужно было настроить мониторинг сервиса поднятого в кубере. Для этого я воспользовался следующими инструментами:
1. minikube - для запуска кластера
2. Nginx - приложение, которые будем монитрорить
3. Prometheus - для сбора метрик
4. Grafana - для визуализации данных  
### Подготовка ###
Я работал на компьютере на Windows, на котором до этого не стояло ничего для работы с кубером. Поэтому перед тем как начать делать задание, нужно было утановить все необходимые инструменты. Пойдём по наростанию сложности установки 
#### minikube ####
Тут всё совсем просто: достаточно зайти на [их сайт](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download), скачать exe файл и запустить его. И всё! Дальше можно в консоли написать minikube и он будет работать. Даже перезагружать ничего не надо!
#### Kubectl ####
Вот сейчас, когда пишу отчёт, узнал, что оказывается Kubectl обязательно устанавливать до minikube. Но у меня всё установилось и в обратном порядке. Тут также надо было скачать файл с [сайта](https://kubernetes.io/releases/download/#binaries), а вот дальше пришлось вспомнинать как добавлять путь в переменную PATH, а потом перезагружаться, чтобы всё заработало. Но после этих манипуляций всё сразу же заработало.
#### Helm ####
Helm нам потребуется, чтобы подтянуть репозитории с Prometheus и Grafana, и установить их. Как поставить его на Windows я понял не сразу (и уже почти пожелел, что начал делать лабу на нём), но потом я узнал, что оказывается в PowerShell есть свой менеджер пакетов **winget**. И можно установить helm одной командой.
~~~ps1
winget install Helm.Helm
~~~
После этой команды можно продолать работать с helm в той же консоли.
Репозитории Prometheus и Grafana далее можно добавить дальше в консоли 
~~~ps1
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
~~~
И вот теперь можно начинать работу!
### Настраиваем кубер ###
Первым делом запустим minikube
~~~ps1
minikube start
~~~
Запустим Prometheus. Репозиторий уже был скачан и теперь достаточно одной команды helm 
~~~ps1
helm install prometheus prometheus-community/prometheus
~~~
Мониторить будем сервер nginx (потому что его легко установить и понятно как можно проверить, что метрики действительно собираются). Для развёртывания использовался специальный файл *deployment.yml* 
~~~yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
          name: nginx-config
      - name: nginx-exporter
        image: nginx/nginx-prometheus-exporter:latest
        args:
          - "-nginx.scrape-uri=http://127.0.0.1:80/stub_status"
        ports:
        - containerPort: 9113
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 80;
        location / {
          root /usr/share/nginx/html;
          index index.html index.htm;
        }
        location /stub_status {
          stub_status on;
          allow 127.0.0.1;
          deny all;
        }
      }
    }

---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  annotations:
    prometheus.io/scrape: 'true'
    prometheus.io/port: '9113'
spec:
  selector:
    app: nginx
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
  - name: metrics
    protocol: TCP
    port: 9113
    targetPort: 9113
  type: ClusterIP
~~~
Здесь важно обратить внимения на раздел annotations, где мы разрешаем мониторинг через Prometheus и указываем порт, на котором он будет развёрнут. А также на раздел, где мы импортируем образ nginx/nginx-prometheus-exporter. (На самом деле подобрать правильные настройки для этого файла было сложнее всего и заняло очень много времени).
Далее, можно развернуть сервер с параметрами из файла одной командой 
~~~ps1
kubectl apply -f nginx-deployment.yaml
~~~
И последнее развёртывание - Графна. Её также устанавливаем через helm
~~~ps1
helm install grafana grafana/grafana
~~~
При установки появляется предложение запустить отдельную команду, чтобы получить пароль админа 
~~~ps1
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
~~~
В PowerShell эта команда не заработала. Но можно заметить, что это составная команда, ошибка была именно в декодировании base64, а вот первая команда работала корректно. Поэтому я полчил пароль в кодировке base64 через первую часть команды. А дальше нашёл [онлайн-декодер](https://www.base64decode.org/) и получил там свой пароль. 
Теперь можно проверить, что все сервисы работают дейстивтельно работают в кластере и получить список подов: 
![image](https://github.com/user-attachments/assets/fa54b4fb-3d8e-4542-96de-54b9c7a645b3)
![image](https://github.com/user-attachments/assets/40b03613-2931-4e58-b48c-293184faf0a6)

И последний шаг на этом этапе свзязать порты подов и порты компьютера
~~~ps1
kubectl --namespace default port-forward grafana-5fc588d9df-w6t86 3000
kubectl port-forward service/prometheus-server 9090:80
kubectl port-forward svc/nginx-service 8081:80
~~~
Коману для графны я брал из подсказки при установки поэтому она указывает нэймспейс, хотя в нашем случае в этом необходимости нет, но главное что работает. Вообще эти команды не особо удобные, так как после запуска каждая полностью занимает окно с консолью, каждый раз приходиться новое окно открывать. Но опять же: зато работает.

### Настраиваем мониторинг ###
Теперь временно можно закрыть сташную и непонятную консоль и перейти в красивый интерфейс графны. Его можно найти на [localhost:3000](localhost:3000). Нас встречает окошко логина, туда надо ввести админский пароль, который я декодировал ранее

![image](https://github.com/user-attachments/assets/c54bdb72-937c-43ef-bf1b-ce97d8f07c46)

Хром даже запомнл этот пароль)
Дальше попадаем на главную страницу

![image](https://github.com/user-attachments/assets/3485cbc3-4dca-4fb0-b7db-1b1ad9e24467)

Прямо центру есть большая кнопка Add your first data source — нам туда! Тут нужно выбрать источник данных — удобно что Prometheus там самый первый в списке 

![image](https://github.com/user-attachments/assets/c174977d-14d9-4d0d-b282-5b5ca37924f8)

Дальше появляется окно с кучей настроеек, но я только добавил адрес Prometheus - [http://prometheus-server.default.svc.cluster.local:80](http://prometheus-server.default.svc.cluster.local:80)

![image](https://github.com/user-attachments/assets/8ca8905b-bfdb-48cc-a904-91eae55784cb)

Далее спускаемся в самый низ страницы и там можно проверить, что источник данных находиться — мне повезло и всё заработало с первого раза 

![image](https://github.com/user-attachments/assets/93eed022-9aa3-4dd3-86ce-748aa63fd985)

Теперь интерфейс предлагает создать создать первый дашборд. Вдохновлённый успехом, я пошёл сразу же создавать дашборд, думая что уже почти сделал лабу. Выбрал какую-то ранодмную метрику, понажимал на кнопки далее и сохранить и получил.....

![image](https://github.com/user-attachments/assets/75f56902-fa43-4eea-934f-d1cb044f353e)

График в виде горизонтальной черты на 0 — крайне информативный! Рандомной метрикой, кстати, оказалась agregator_discovery_aggregation_count_total (что это вообще?). Решил, что такого классного графика, наверное, будет недостаточно, поэтому дальше пришлось думать, какие метрики можно было бы собрать, чтобы они были не равные 0.
### Проверяем мониторинг ###
Полистав список метрик, я увидел название kubelet_http_requests_total. Мы монитром веб сервер, поэтому вроде бы метрика должна как раз подойти. Эта матрика считает http запросы, значит, чтобы увидеть график, нужно эти запросы отправлять. Для этого я написал простой Powershell скрипт, который будет отправлять запросы на адрес nginx сервера с интервалом в 1 секунду 
~~~ps1
while ($true) {
    try {
        Invoke-WebRequest -Uri "http://localhost:8081" -UseBasicParsing | Out-Null
        Write-Output "Request sent successfully."
    } catch {
        Write-Output "Request failed: $_"
    }
    Start-Sleep -Seconds 1
}
~~~
Заработало не сразу, но зато после всех правок в консоли появились заветные сообщения Request sent successfully, появляющиеся с нужными инетрвалами. Теперь можно составить дашборд с выбранной метрикой и посмотреть, что там отображается

![image](https://github.com/user-attachments/assets/95b01e97-def9-4454-b32b-d8f10fc3d760)

Пока писал отчёт до этого места, мой скрипт спамил сервер запросами. Интервал запросов всегда был одинаковый, поэтому общее число запросов увеличивалось линейно. Этот график уже более информативный. По нему можно понять, что запросы действительно доходят до сервера, то есть под с nginx скорее всего работает корректно.
## Звёздочка

![image](https://github.com/user-attachments/assets/81b85fd8-31dc-4c90-8878-880320c48724)
