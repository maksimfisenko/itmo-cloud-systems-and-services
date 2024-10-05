FROM python:3.11

WORKDIR /var/www/html

COPY ./static .

EXPOSE 8081
CMD ["python3", "-m", "http.server", "8081"]
