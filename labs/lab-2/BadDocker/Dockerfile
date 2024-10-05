FROM ubuntu:latest

RUN apt-get update
RUN apt-get -y install python3

ADD ./static .

EXPOSE 8081
CMD ["python3", "-m", "http.server", "8081"]
