FROM ubuntu:16.04

# Install OpenJDK-8
RUN apt-get update && \
    apt-get install -y openjdk-8-jdk && \
    apt-get install -y ant && \
    apt-get clean;


# Install  perl 
RUN  apt-get install -y perl    

# Install csh
RUN  apt-get install -y csh


# Setup JAVA_HOME -- useful for docker commandline
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

# Install jr 
ENV JR_HOME /usr/local/jr

ENV PATH="$PATH:/usr/local/jr/bin"
RUN echo $PATH
# FROM ubuntu:16.04
# RUN  apt-get update \
#   && apt-get install -y wget \
#   && rm -rf /var/lib/apt/lists/*

# Define working directory.
WORKDIR /jr_code


# Define default command.
CMD ["bash"]