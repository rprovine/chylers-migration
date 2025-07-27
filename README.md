# Chyler's Hawaiian Beef Chips - Website Migration Project

This repository contains all the documentation, scripts, and checklists needed to perform a zero-downtime migration of the Chyler's Hawaiian Beef Chips website.

## Project Structure

```
chylers-migration/
├── docs/                       # Documentation files
│   ├── COMPREHENSIVE_SITE_AUDIT.md    # Complete site audit checklist
│   ├── DATA_MIGRATION_PLAN.md         # Detailed migration strategy
│   └── ZERO_DOWNTIME_DEPLOYMENT.md    # Deployment procedures
├── scripts/                    # Migration scripts
│   ├── export/                # Data export scripts
│   │   ├── export_all_data.sh         # Master export script
│   │   ├── export_customers_json.php  # Customer export to JSON
│   │   ├── export_products_json.php   # Product export to JSON
│   │   └── download_product_images.php # Product image downloader
│   └── validation/            # Validation scripts
│       ├── pre_migration_check.sh     # Pre-migration validation
│       └── verify_migration.sh        # Post-migration verification
├── checklists/                # Functional checklists
│   └── FUNCTIONALITY_PRESERVATION_CHECKLIST.md
├── data/                      # Data storage (gitignored)
│   ├── exports/              # Exported data files
│   └── backups/              # Database backups
└── README.md                  # This file
```

## Quick Start

### 1. Set Database Credentials
```bash
export DB_HOST=your_host
export DB_USER=your_user
export DB_PASS=your_password
export DB_NAME=chylers_db
```

### 2. Run Pre-Migration Validation
```bash
cd scripts/validation
./pre_migration_check.sh
```

### 3. Export All Data
```bash
cd scripts/export
./export_all_data.sh
```

### 4. Verify Migration (After Import)
```bash
cd scripts/validation
./verify_migration.sh
```

## Key Documents

### Site Audit Checklist
`docs/COMPREHENSIVE_SITE_AUDIT.md` - Complete checklist of all current site features and data to be preserved.

### Data Migration Plan
`docs/DATA_MIGRATION_PLAN.md` - Detailed plan including:
- Export strategies for all data types
- SQL queries and PHP scripts
- Validation procedures
- Security considerations

### Zero-Downtime Deployment
`docs/ZERO_DOWNTIME_DEPLOYMENT.md` - Step-by-step deployment procedures including:
- DNS strategy
- Data synchronization
- Rollback procedures
- Success metrics

### Functionality Checklist
`checklists/FUNCTIONALITY_PRESERVATION_CHECKLIST.md` - Comprehensive list of all features that must work after migration.

## Critical Data to Preserve

### Customer Data
- Login credentials (password hashes)
- Contact information
- Order history
- Saved addresses
- Payment methods (tokenized)

### Product Catalog
- All flavors and sizes
- Current pricing
- Product images
- Inventory levels
- SEO metadata

### Business Logic
- Shipping calculations
- Tax rates
- Free shipping thresholds
- Will Call pickup system
- Discount codes

## Migration Timeline

- **T-14 days**: Set up infrastructure
- **T-7 days**: Initial full data sync
- **T-5 days**: Test migration on staging
- **T-1 day**: Final data sync
- **T-0**: DNS cutover (2:00 AM HST recommended)
- **T+1**: Post-migration verification

## Emergency Contacts

Update these before migration:
- Technical Lead: [Name] - [Phone]
- Database Admin: [Name] - [Phone]
- Business Owner: [Name] - [Phone]

## Important Notes

1. **Always test on staging first** - Never run migration scripts directly on production
2. **Backup everything** - Take multiple backups before starting
3. **Monitor closely** - Watch all systems during and after migration
4. **Communicate** - Keep stakeholders informed throughout the process
5. **Document changes** - Record any deviations from the plan

## Support

For questions about this migration plan, please contact the technical team.

---

*Last Updated: [Current Date]*
*Migration Plan Version: 1.0*