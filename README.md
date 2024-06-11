## Introducción a la Concurrencia - UNTDF

# README jr_docker_ic

## Getting started

This is a docker container for JR Concurrent Language programming

### Clone repo

    git clone https://github.com/luisf09/jr_docker_ic.git

### Up container

> ***En caso de necesitar una imagen que no sea basada en debian renombrar DockerfileAlpine -> Dockerfile***

    docker compose up -d

### Enter to container

    docker exec -it jr_docker_ic bash

> Si usaste el dockerfile basado en alpine reemplazar bash por sh
    
    
### Execute a jr program

    jr program_name

### Rebuild container

    docker compose up -d --build

### Down container

    docker compose down

### or

    docker stop id_container

### List containers

    docker ps

### List images

    docker images ls

### Remove image

    docker rmi id_image

## Author

> Luis Rojas -> lrojasflores@untdf.edu.ar

> Horacio Pendenti -> hpendenti@untdf.edu.ar
