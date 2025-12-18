FROM faelcavalheri/biblivre5-docker:legacy

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Sao_Paulo \
    JAVA_TOOL_OPTIONS="-Duser.timezone=America/Sao_Paulo -Duser.country=BR -Duser.language=pt"

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --allow-unauthenticated --no-install-recommends tzdata dos2unix && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo "$TZ" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

COPY lib/postgresql-42.2.27.jar /usr/local/tomcat/lib/postgresql-42.2.27.jar

COPY start_biblivre.sh /start_biblivre.sh
COPY setenv.sh /usr/local/tomcat/bin/setenv.sh

RUN dos2unix /start_biblivre.sh /usr/local/tomcat/bin/setenv.sh && \
    chmod +x /start_biblivre.sh

ENTRYPOINT ["/bin/bash", "/start_biblivre.sh"]