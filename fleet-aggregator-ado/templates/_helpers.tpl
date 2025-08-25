{{/*
Build a Kustomize remote resource URL for Azure DevOps Git.

Supports:
- SSH   : git@ssh.dev.azure.com:v3/<org>/<project>/<repo>
- HTTPS : https://dev.azure.com/<org>/<project>/_git/<repo>

Returned string is: git::<git-url>//<path>?ref=<ref>
*/}}
{{- define "ado.remote.url" -}}
{{- $svc := .svc -}}
{{- $protocol := default $.Values.defaults.protocol $svc.protocol -}}
{{- $org := required "service.org is required" $svc.org -}}
{{- $project := required "service.project is required" $svc.project -}}
{{- $repo := required "service.repo is required" $svc.repo -}}
{{- $path := required "service.path is required" $svc.path -}}
{{- $ref := required "service.ref is required"  $svc.ref -}}

{{- if eq $protocol "ssh" -}}
{{- /* SSH form */ -}}
{{- printf "git::git@ssh.dev.azure.com:v3/%s/%s/%s//%s?ref=%s" $org $project $repo $path $ref -}}
{{- else -}}
{{- /* HTTPS form */ -}}
{{- /* NOTE: If your project name contains spaces, ensure it is URL-encoded in values. */ -}}
{{- printf "git::https://dev.azure.com/%s/%s/_git/%s//%s?ref=%s" $org $project $repo $path $ref -}}
{{- end -}}
{{- end -}}

{{/*
Compute replicas for a service (svc.replicas || defaultReplicas)
*/}}
{{- define "ado.replicas" -}}
{{- $svc := .svc -}}
{{- $rep := default $.Values.defaultReplicas $svc.replicas -}}
{{- $rep -}}
{{- end -}}
