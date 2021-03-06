{% from "mysql/defaults.yaml" import rawmap with context %}
{%- set mysql = salt['grains.filter_by'](rawmap, grain='os', merge=salt['pillar.get']('mysql:lookup')) %}

{% set mysql_root_user = salt['pillar.get']('mysql:server:root_user', 'root') %}
{% set mysql_root_pass = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set mysql_host = salt['pillar.get']('mysql:server:host', 'localhost') %}
{% set db_states = [] %}

include:
  - mysql.python

{% for database in salt['pillar.get']('mysql:database', []) %}
{% set state_id = 'mysql_db_' ~ loop.index0 %}
{{ state_id }}:
  mysql_database.present:
    - name: {{ database }}
    - connection_host: '{{ mysql_host }}'
    - connection_user: '{{ mysql_root_user }}'
    {% if mysql_root_pass %}
    - connection_pass: '{{ mysql_root_pass }}'
    {% endif %}
    - connection_charset: utf8

{% if salt['pillar.get'](['mysql', 'schema', database, 'load']|join(':'), False) %}
{{ state_id }}_schema:
  file.managed:
    - name: /etc/mysql/{{ database }}.schema
    - source: {{ salt['pillar.get'](['mysql', 'schema', database, 'source']|join(':')) }}
{%- set template_type = salt['pillar.get'](['mysql', 'schema', database, 'template']|join(':'), False) %}
{%- if template_type %}
    - template: {{ template_type }}
{% endif %}
    - user: {{ salt['pillar.get']('mysql:server:user', 'mysql') }}
    - makedirs: True

{{ state_id }}_load:
  cmd.wait:
    - name: mysql -u {{ mysql_root_user }} -p{{ mysql_root_pass }} {{ database }} < /etc/mysql/{{ database }}.schema
    - watch:
      - file: {{ state_id }}_schema
      - mysql_database: {{ state_id }}
{% endif %}

{% do db_states.append(state_id) %}
{% endfor %}
