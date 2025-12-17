FROM faelcavalheri/biblivre5-docker:legacy

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Sao_Paulo \
    JAVA_TOOL_OPTIONS="-Duser.timezone=America/Sao_Paulo -Duser.country=BR -Duser.language=pt"

RUN apt-get update && \
    apt-get install -y --no-install-recommends tzdata && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo "$TZ" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

COPY lib/postgresql-42.2.27.jar /usr/local/tomcat/lib/postgresql-42.2.27.jar

ADD start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

ENTRYPOINT ["/bin/bash","-lc","/usr/local/bin/start.sh"]