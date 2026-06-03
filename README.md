# Infraestrutura de Dados para Treinamento de IA

Este projeto define uma infraestrutura Terraform para processamento de dados e execução de modelos de IA.

## Objetivo

A infraestrutura é voltada para:
- Ingestão e armazenamento de dados brutos,
- Processamento e transformação de imagens,
- Execução de lógica de treino/serviço de IA usando AWS Lambda,
- Provisionamento de recursos de rede, buckets S3, EC2 e execução em lote.

O foco principal é criar um pipeline de dados para treinamento de IA e também suportar a execução de um modelo já treinado.

## Estrutura do projeto

Arquivos Terraform:
- `provider.tf` - configura o provedor AWS.
- `vpc.tf` - define a rede privada, sub-redes e roteamento.
- `security_groups.tf` - configura regras de segurança para serviços.
- `s3.tf` - cria buckets S3 para armazenamento de dados.
- `ec2.tf` - provisiona instâncias EC2, se necessário.
- `lambda.tf` - define funções Lambda e suas permissões.
- `batch.tf` - configura trabalhos em lote (batch processing).
- `main.tf` - orquestra os módulos/recursos principais.
- `outputs.tf` - exporta valores úteis da infraestrutura.
- `variables.tf` - declara variáveis de entrada do Terraform.

Arquivos de suporte:
- `batch_process.py` - script Python de orquestração/executações de lote.
- `lambda_client_images_processing/` - código-fonte Python da Lambda de processamento de imagens.
- `lambda_database_download/` - código-fonte Python da Lambda de download de dados.

Arquivos ZIP de deployment:
- `lambda_client_images_processing.zip`
- `lambda_database_download.zip`

## Como usar

1. Configure as variáveis de ambiente AWS ou `terraform.tfvars` para credenciais e parâmetros do provedor.
2. Execute `terraform init` para inicializar o ambiente.
3. Execute `terraform plan` para revisar as alterações.
4. Execute `terraform apply` para criar os recursos.

## Deploy das funções Lambda

As funções Lambda usam código Python que deve ser empacotado em arquivos ZIP antes de subir.

### Passos importantes

1. Apagar a versão anterior do pacote ZIP antes de gerar o novo.
2. Recriar o ZIP a partir do diretório do código-fonte.
3. Atualizar o arquivo ZIP usado pelo Terraform ou pelo fluxo de deployment.

Por exemplo:

```powershell
Remove-Item lambda_client_images_processing.zip
Remove-Item lambda_database_download.zip
Compress-Archive -Path lambda_client_images_processing\* -DestinationPath lambda_client_images_processing.zip
Compress-Archive -Path lambda_database_download\* -DestinationPath lambda_database_download.zip
```

> Importante: sempre delete o arquivo ZIP anterior antes de criar uma nova versão. Isso evita que o pacote antigo seja enviado por engano e garante que a Lambda use o código atualizado.

## Considerações

- Mantenha os arquivos de estado do Terraform (`*.tfstate`) fora do repositório.
- Use o `.gitignore` existente para ignorar diretórios e arquivos gerados, como `.terraform/`, `*.tfstate`, `terraform.tfvars`, entre outros.
- Verifique as dependências Python necessárias para rodar as Lambdas localmente e inclua-as no pacote se necessário.
