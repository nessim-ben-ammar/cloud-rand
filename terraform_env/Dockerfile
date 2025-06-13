# Use official HashiCorp Terraform image as base
FROM hashicorp/terraform:light

# Add entrypoint script
COPY aws_creds /aws_creds
RUN chmod +x /aws_creds

ENTRYPOINT ["/aws_creds"]
CMD ["sh"]
