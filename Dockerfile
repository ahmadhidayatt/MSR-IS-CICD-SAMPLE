FROM ibmwebmethods.azurecr.io/webmethods-microservicesruntime:11.1.0.11

COPY --chown=1724:1724 ./helmchart/config/dev/monitor.cnf/ ${SAG_HOME}/IntegrationServer/config/monitor/



COPY --chown=1724:1724 ./packages/WmJDBCAdapter ${SAG_HOME}/IntegrationServer/packages/WmJDBCAdapter/


USER root
RUN chown -R 1724:1724 /opt/softwareag

USER 1724