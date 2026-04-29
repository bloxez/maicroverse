# HR Graph

**Warning**

Running the `HR Graph` setup will wipe all data from this project and create the graph and data needed for you to have a fully functioning HR employment tracking system. Existing data and any files you have uploaded will all be deleted.

Please proceed with caution.

It is recommend that you use the `Root Project` to create a learning instance, or you can even create multiple instances and place each example project in its own instance.

## Introduction

The HR Graph project demonstrates how to build sophisticated business logic using mAIcro's Apache AGE graph database and Cypher wrappers. Instead of traditional relational tables, this example uses graph nodes and edges to model a realistic employment tracking system with temporal validity and automatic enforcement of business rules.

This example showcases core mAIcro features:

- **Apache AGE Graph Database** — Store employees and employers as nodes, with employment relationships as edges
- **Cypher Wrappers** — GraphQL-wrapped Cypher operations that execute complex graph queries with built-in business logic
- **Temporal Tracking** — Employment history with `valid_from` and `valid_to` timestamps, enabling point-in-time queries
- **Business Rule Enforcement** — Wrappers automatically enforce constraints (e.g., one active full-time role per employee)
- **Audit History** — All employment changes are logged with temporal validity for compliance
- **Pure Graph Model** — No SQL tables needed—everything is graph nodes and edges
- **Reusable Operations** — Named wrappers can be called from any GraphQL client

## What You'll Build

Running the setup creates a graph with these node types and relationships:

| Node Type | Purpose | Examples |
|-----------|---------|----------|
| **Employee** | Individual workers | Alice Chen, Bob Okafor, David Park, Femi Adeyemi, Carmen Silva, Emma Johnson |
| **Employer** | Companies | Axiom Labs, BluePeak Tech, Cornerstone, DeltaCore, EchoVentures |

| Edge Type | Purpose | Temporal Tracking |
|-----------|---------|-------------------|
| **EmployedBy** | Full-time employment | `valid_from`, `valid_to` — only one active per employee |
| **ContractedBy** | Part-time/contract work | `valid_from`, `valid_to` — only if no active full-time role |

The setup script will:

1. ✅ Enable Apache AGE and create the `hr` graph
2. ✅ Register three GraphQL-wrapped Cypher operations
3. ✅ Seed 6 employees and 5 employers as graph nodes
4. ✅ Build realistic multi-year employment histories
5. ✅ Enforce business rules (full-time exclusivity, part-time constraints)

## Getting Started

1. Open the HR Graph project in mAIcro
2. Navigate to the **Scripts** section
3. Run `01.hr_graph_setup.gql` — this orchestrates all setup steps
4. Once complete, you'll have three GraphQL operations available

Example queries and mutations you can run:

```graphql
# Get all current full-time employees
query {
  GetCurrentEmployers {
    data {
      employee { properties { name } }
      employer { properties { name } }
      role
    }
  }
}

# Add a new full-time employee (automatically closes previous role if any)
mutation {
  AddFullTimeEmployer(
    employee: "Sarah Martinez"
    employer: "Axiom Labs"
    role: "Engineering Manager"
    valid_from: "2024-01-15"
  ) {
    data { success message }
  }
}

# Add a part-time contract role (skipped if employee has active full-time role)
mutation {
  AddPartTimeEmployer(
    employee: "Carmen Silva"
    employer: "EchoVentures"
    role: "Consultant"
    valid_from: "2024-03-01"
  ) {
    data { success message }
  }
}

# Query employment history for a specific employee
query {
  GraphQuery(
    query: """
    MATCH (e:Employee {name: $employee})-[emp:EmployedBy]-(employer:Employer)
    RETURN e, emp, employer
    ORDER BY emp.valid_from DESC
    """
    variables: { employee: "Alice Chen" }
  ) {
    data
  }
}
```

## Key mAIcro Concepts Demonstrated

### Apache AGE Graph Database

Unlike traditional SQL tables, Apache AGE models data as:
- **Nodes** — Entities (employees, employers)
- **Edges** — Relationships with properties (employment, contracts)
- **Properties** — Attributes on nodes and edges (name, email, role, dates)

Benefits:
- Natural representation of relationships
- Efficient path queries and graph algorithms
- Flexible schema (add properties without migrations)

### Cypher Wrappers

Cypher is the query language for property graphs. mAIcro's Cypher wrappers:
- Execute complex Cypher queries through a GraphQL interface
- Encapsulate business logic (e.g., "close the previous role before opening a new one")
- Are registered as named, reusable operations
- Accept parameters and return typed results

### Business Rule Enforcement

The `AddFullTimeEmployer` wrapper enforces critical rules:

```
1. Accept parameters: employee name, employer, role, valid_from, valid_to
2. Find the employee node
3. If an open EmployedBy edge exists:
   - Set its valid_to = today
4. Create new EmployedBy edge with the new role
5. Return success/failure
```

This ensures **data integrity without application code** — the rules live in the graph layer.

### Temporal Validity

Every employment edge has:
- `valid_from` — When this role started
- `valid_to` — When it ended (null = currently active)

This enables:
- **Point-in-time queries** — "Who reported to this manager on 2023-06-15?"
- **Duration analysis** — "How long has Alice been at BluePeak Tech?"
- **Audit trails** — Complete history of all employment changes
- **Compliance** — Prove who was employed during any period

### Part-Time Employment Rules

The `AddPartTimeEmployer` wrapper:
- Allows multiple concurrent part-time roles
- But **skips** if the employee has an active full-time role
- Ensures realistic employment models (full-time excludes part-time)

## Employee Profiles

The seed data creates realistic career tracks:

| Employee | Career Track | Current Status |
|----------|--------------|-----------------|
| **Alice Chen** | Full-time track | Senior Engineer at BluePeak Tech (since 2023-07-01) |
| **Bob Okafor** | Full-time track | Head of Product at DeltaCore (since 2022-05-01) |
| **David Park** | Full-time track | Platform Lead at Axiom Labs (since 2021-09-01) |
| **Femi Adeyemi** | Full-time track | Designer at BluePeak Tech (since 2023-06-01) |
| **Carmen Silva** | Mixed (freelancer) | Multiple concurrent part-time roles |
| **Emma Johnson** | Mixed (freelancer) | Multiple concurrent part-time roles |

## Running the Scripts

The setup is split into numbered scripts for modularity:

- **01.hr_graph_setup.gql** — Master orchestrator (run this!)
- **02.graph_bootstrap.gql** — Enable Apache AGE, create the `hr` graph
- **03.register_wrappers.gql** — Register Cypher wrappers as GraphQL operations
- **04.seed_nodes.gql** — Create 6 employee and 5 employer nodes
- **05.seed_employment.gql** — Build employment history with temporal validity
- **06.verify.gql** — Test that all operations work correctly

Each script includes documentation explaining what it does and why.

## Extending the Project

Try these modifications:

1. **Add more roles** — Extend with contractor, internship, or sabbatical edges
2. **Department structure** — Add Department nodes and relationships for org charts
3. **Salary tracking** — Store compensation history on employment edges
4. **Reporting chains** — Add ReportsTo edges to model management hierarchies
5. **Skills graph** — Track employee skills and required skills per role
6. **Analytics queries** — Calculate tenure, turnover, career paths, org structure health
7. **Webhooks** — Trigger notifications when employment changes occur
8. **Compliance reports** — Audit all changes within a date range

## Common Patterns

### Query a Single Employee's History

```graphql
query {
  GraphQuery(
    query: """
    MATCH (e:Employee {name: $name})-[emp:EmployedBy|ContractedBy]-(employer:Employer)
    RETURN 
      e.name as employee,
      employer.name as employer,
      emp.role as role,
      emp.valid_from as started,
      emp.valid_to as ended
    ORDER BY emp.valid_from DESC
    """
    variables: { name: "Alice Chen" }
  ) { data }
}
```

### Find Current Team Members

```graphql
query {
  GraphQuery(
    query: """
    MATCH (employer:Employer {name: $company})-[emp:EmployedBy]-(e:Employee)
    WHERE emp.valid_to IS NULL
    RETURN e.name as name, emp.role as role
    ORDER BY e.name
    """
    variables: { company: "Axiom Labs" }
  ) { data }
}
```

### Promote an Employee

```mutation
mutation {
  AddFullTimeEmployer(
    employee: "Alice Chen"
    employer: "BluePeak Tech"
    role: "Principal Engineer"
    valid_from: "2024-06-01"
  ) { data }
}
```

This automatically closes her previous "Senior Engineer" role and creates the new one.

## Next Steps

- Read the [Apache AGE Reference](/reference/age) to understand graph concepts
- Explore [Cypher Query Language](/docs/cypher) for advanced graph patterns
- Learn [Temporal Queries](/docs/temporal) for point-in-time analysis
- Check out [GraphQL Wrappers](/docs/graphql-wrappers) to create custom operations
- Review [Graph Best Practices](/docs/graph-patterns) for schema design
