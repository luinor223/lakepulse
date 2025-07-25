# Data Directory

This directory contains sample datasets and bootstrap data for the LakePulse project.

## Sample Datasets

### Wide World Importers Database

The primary dataset used in this project is Microsoft's **Wide World Importers** sample database, which represents a fictional wholesale novelty goods importer and distributor.

#### Download Source
```bash
# Download the PostgreSQL dump file
curl -L -o wide_world_importers_pg.dump \
  https://github.com/Azure/azure-postgresql/raw/master/samples/databases/wide-world-importers/wide_world_importers_pg.dump
```

**Official Source**: [Azure PostgreSQL Samples](https://github.com/Azure/azure-postgresql/blob/master/samples/databases/wide-world-importers/wide_world_importers_pg.dump)

#### Database Schema Overview

The Wide World Importers database contains the following key tables:

| Schema | Tables | Description |
|--------|---------|-------------|
| `Application` | People, Countries, StateProvinces | System configuration and reference data |
| `Sales` | Customers, Orders, OrderLines, Invoices | Sales transactions and customer data |
| `Purchasing` | Suppliers, PurchaseOrders, PurchaseOrderLines | Procurement and supplier management |
| `Warehouse` | StockItems, StockItemTransactions, StockGroups | Inventory and warehouse operations |

#### Data Characteristics

- **Size**: ~100MB compressed, ~500MB uncompressed
- **Records**: ~1M+ transactions across all tables
- **Time Range**: 2013-2016 (with some future-dated records for demonstration)
- **Use Cases**: OLTP, OLAP, Data Warehousing, CDC simulation