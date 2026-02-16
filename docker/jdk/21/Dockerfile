# Use a base image with Java (Alpine is a good choice for smaller images)
FROM eclipse-temurin:21

# Set the working directory
WORKDIR /app

RUN sed -i "s@http://.*archive.ubuntu.com@https://mirrors.sustech.edu.cn@g" /etc/apt/sources.list && \
    sed -i "s@http://.*security.ubuntu.com@https://mirrors.sustech.edu.cn@g" /etc/apt/sources.list

