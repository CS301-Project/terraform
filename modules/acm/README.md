# modules/acm

Public ACM certificate (NOT Private CA) for **itsag3t2.com** (and **www.itsag3t2.com**) with DNS validation in Route 53.

- **Region:** Hard-coded to `us-east-1` (required by CloudFront)
- **Cost safeguards:**
  - Uses **public ACM** (free). **No ACM Private CA** (which costs ~$400/month).
  - Does **not** touch/delete your existing Route 53 hosted zone (no risk of ~$100/domain recovery).
  - Does **not** enable **AWS Shield Advanced** (which costs ~$3,000/month).

## Files
- `main.tf` – certificate request + DNS validation records
- `versions.tf` – provider requirements
- `outputs.tf` – `certificate_arn`

## How to use in root
Add this to your root without variables (hard-coded, as requested):

```hcl
module "acm" {
  source = "./modules/acm"
}
```

Then, in your CloudFront module/resource, set:

```hcl
acm_certificate_arn = module.acm.certificate_arn
```

> Note: CloudFront distributions must use a certificate in **us-east-1**.