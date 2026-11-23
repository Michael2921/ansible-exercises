FROM eclipse-temurin:21-jdk
EXPOSE 8080
RUN mkdir /opt/app
COPY build/libs/build-tools-exercises-1.0-SNAPSHOT.jar /opt/app
WORKDIR /opt/app
CMD ["java", "-jar", "build-tools-exercises-1.0-SNAPSHOT.jar"] 