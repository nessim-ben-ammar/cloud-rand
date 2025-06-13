# Use official HashiCorp Terraform image as base
FROM hashicorp/terraform:light

# Add entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["sh"]
