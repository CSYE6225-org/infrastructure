# infrastructure

In order to use this follow the steps bellow


1. git clone the repository
2. run terraform init
3. Add tfvars file to the folder
4. Run terraform apply to apply the config
5. Run terraform destroy to destroy the setup

Command to import AWS SSL cert:

aws acm import-certificate --certificate fileb://prod_maneesh_me.crt --certificate-chain fileb://prod_maneesh_me.ca-bundle --private-key fileb://private.key --profile prod