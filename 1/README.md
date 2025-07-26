<h2>README</h2>

<p>
This infrastructure stack powers a self-contained platform for developing, deploying, observing, and managing modern distributed systems.
It combines a set of UI interfaces with a supporting suite of backend services that provide messaging, orchestration, identity, storage, monitoring, and security services.
</p>

<table>
  <tr>
    <td>
      <a href="https://akhq.aldous.info/">AKHQ</a><br>
      <em>Kafka cluster management</em><br>
      <img src="docs/screenshots/akhq.png" width="200"/>
    </td>
    <td>
      <a href="https://alertmanager.aldous.info/">Alertmanager</a><br>
      <em>Alert routing and management</em><br>
      <img src="docs/screenshots/alertmanager.png" width="200"/>
    </td>
    <td>
      <a href="https://blackbox.aldous.info/">Blackbox</a><br>
      <em>Endpoint monitoring exporter</em><br>
      <img src="docs/screenshots/blackbox.png" width="200"/>
    </td>
    <td>
      <a href="https://cadence.aldous.info/">Cadence</a><br>
      <em>Workflow orchestration</em><br>
      <img src="docs/screenshots/cadence.png" width="200"/>
    </td>
  </tr>
  <tr>
    <td>
      <a href="https://docs.aldous.info/">Docs</a><br>
      <em>Documentation portal</em><br>
      <img src="docs/screenshots/docs.png" width="200"/>
    </td>
    <td>
      <a href="https://gitlab.aldous.info/">GitLab</a><br>
      <em>GitLab CE instance</em><br>
      <img src="docs/screenshots/gitlab.png" width="200"/>
    </td>
    <td>
      <a href="https://grafana.aldous.info/">Grafana</a><br>
      <em>Metrics dashboards</em><br>
      <img src="docs/screenshots/grafana.png" width="200"/>
    </td>
    <td>
      <a href="https://jaeger.aldous.info/">Jaeger</a><br>
      <em>Distributed tracing</em><br>
      <img src="docs/screenshots/jaeger.png" width="200"/>
    </td>
  </tr>
  <tr>
    <td>
      <a href="https://keycloak.aldous.info/">Keycloak</a><br>
      <em>Identity & access management</em><br>
      <img src="docs/screenshots/keycloak.png" width="200"/>
    </td>
    <td>
      <a href="https://kuma.aldous.info/">Kuma</a><br>
      <em>Service mesh / API gateway</em><br>
      <img src="docs/screenshots/kuma.png" width="200"/>
    </td>
    <td>
      <a href="https://mailhog.aldous.info/">MailHog</a><br>
      <em>Email testing tool</em><br>
      <img src="docs/screenshots/mailhog.png" width="200"/>
    </td>
    <td>
      <a href="https://minio.aldous.info/">MinIO</a><br>
      <em>S3-compatible storage</em><br>
      <img src="docs/screenshots/minio.png" width="200"/>
    </td>
  </tr>
  <tr>
    <td>
      <a href="https://nui.aldous.info/">NUI</a><br>
      <em>Durable at-least-once streams</em><br>
      <img src="docs/screenshots/nui.png" width="200"/>
    </td>
    <td>
      <a href="https://pgadmin.aldous.info/">pgAdmin</a><br>
      <em>PostgreSQL admin tool</em><br>
      <img src="docs/screenshots/pgadmin.png" width="200"/>
    </td>
    <td>
      <a href="https://postgraphile.aldous.info/graphiql">PostGraphile</a><br>
      <em>GraphQL API for Postgres</em><br>
      <img src="docs/screenshots/postgraphile.png" width="200"/>
    </td>
    <td>
      <a href="https://promtail.aldous.info/">Promtail</a><br>
      <em>Log collector for Loki</em><br>
      <img src="docs/screenshots/promtail.png" width="200"/>
    </td>
  </tr>
  <tr>
    <td>
      <a href="https://redisinsight.aldous.info/">RedisInsight</a><br>
      <em>Redis visualization</em><br>
      <img src="docs/screenshots/redisinsight.png" width="200"/>
    </td>
    <td>
      <a href="https://search.aldous.info/">Search</a><br>
      <em>Internal search service</em><br>
      <img src="docs/screenshots/search.png" width="200"/>
    </td>
    <td>
      <a href="https://sentry.aldous.info/">Sentry</a><br>
      <em>Error monitoring</em><br>
      <img src="docs/screenshots/sentry.png" width="200"/>
    </td>
    <td>
      <a href="https://sonarqube.aldous.info/">SonarQube</a><br>
      <em>Code quality analysis</em><br>
      <img src="docs/screenshots/sonarqube.png" width="200"/>
    </td>
  </tr>
</table>

<p>
Additional <strong>non-UI services</strong> play critical roles in the platform’s core functionality:
</p>

<ul>
  <li><code>kafka</code>, <code>nats</code>: messaging and event streaming systems</li>
  <li><code>postgres</code>, <code>pgbouncer</code>: primary relational data store and connection pooling</li>
  <li><code>presidio</code>: text data anonymization and redaction (via analyzer, anonymizer, redactor)</li>
  <li><code>prometheus</code>: metrics collection for system observability</li>
  <li><code>loki</code>, <code>promtail</code>: centralized log aggregation and shipping</li>
  <li><code>opensearch</code>: full-text indexing and advanced search capabilities</li>
  <li><code>caddy</code>: TLS-enabled reverse proxy and automatic certificate management</li>
  <li><code>kong</code>: programmable API gateway with plugin support and auth handling</li>
  <li><code>cadence</code>, <code>collector</code>: distributed workflow orchestration and background processing</li>
  <li><code>exporter</code>: system-level and custom metrics exposure</li>
</ul>

<p>
This repository includes a <code>Makefile</code> with the following targets:
</p>

<ul>
  <li><code>setup</code>: prepares initial configuration and resources</li>
  <li><code>install</code>: pulls containers and applies configurations</li>
  <li><code>clean</code>: stops services and prunes unused resources</li>
  <li><code>purge</code>: performs a deep clean including persistent volumes</li>
  <li><code>backup</code>: copies environment and pesistent volume to remote cloud</li>
  <li><code>restore</code>: restores environment to any docker enabled cloud</li>
</ul>
