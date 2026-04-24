# Book Club

**Warning**

Running the `Book Club` setup will wipe all data from this project and create the tables and data needed for you to have a fully functioning Book Club project. Existing data tables and any files you have uploaded will all be deleted.

Please proceed with caution.

It is recommend that you use the `Root Project` to create a learning instance, or you can even create multiple instances and place each example project in its own instance.

## Introduction

The Book Club project demonstrates how to build a modern web application using mAIcro's GraphQL-first approach. It showcases a multi-table relational database for a community of readers who discover, rate, and discuss books together.

This example brings together core mAIcro features:

- **Auto-Generated GraphQL API** — Define your database schema once, and mAIcro instantly generates a complete CRUD API (add, update, delete, query) for every table
- **Semantic Search with Vector Embeddings** — Book synopses are automatically embedded and searchable by meaning, not just keywords
- **Graph Integration** — SQL rows sync automatically to an Apache AGE graph, enabling relationship queries and social network analysis
- **Row-Level Security** — Team isolation filters ensure users see only data they're authorized to access
- **File Storage** — Attach and manage files (book covers, author photos) natively
- **Sensitive Data Protection** — Fields like passwords and email addresses are automatically redacted for non-admin users
- **Full-Text Search** — Instantly search reviews and book descriptions
- **Async Jobs** — Long-running operations like bulk imports run in the background

## What You'll Build

Running the setup creates five tables:

| Table | Purpose | Key Features |
|-------|---------|--------------|
| **readers** | Book club members | Usernames, membership levels, private notes (sensitive) |
| **authors** | Book creators | Demographics (JSON), bios, contact info (sensitive) |
| **books** | Catalog entries | Titles, genres, synopses (vector-embedded for semantic search), pricing (sensitive) |
| **reviews** | Reader feedback | Star ratings (1-5), written reviews, timestamps, reviewer IP (sensitive) |
| **team_notes** | Internal documentation | Private notes visible only to authorized team members |

The setup script will:

1. ✅ Clear all existing data and start fresh
2. ✅ Enable File Storage, Full-Text Search, and Async Jobs
3. ✅ Create the `TeamIsolation` filter for row-level security
4. ✅ Define all five tables with proper field types and security rules
5. ✅ Sync data to an Apache AGE graph for relationship analysis
6. ✅ Seed realistic book, author, reader, and review data
7. ✅ Build a social graph showing reader connections

## Getting Started

1. Open the Book Club project in mAIcro
2. Navigate to the **Scripts** section
3. Run `01.book_club_setup.gql` — this orchestrates all setup steps
4. Once complete, you'll have immediate access to GraphQL queries and mutations

Example queries you can run:

```graphql
# List all books with their authors
query {
  books(page: {limit: 10}) {
    data {
      id title genre author_id
    }
  }
}

# Search books semantically by topic
query {
  booksSemanticSearch(query: "mystery and suspense", limit: 5) {
    data { id title synopsis }
  }
}

# Find top-rated books
query {
  books(
    where: {rating: {gte: 4}}
    page: {limit: 10}
  ) {
    data { id title genre }
  }
}

# Add a new review
mutation {
  reviewAdd(data: {
    rating: 5
    review: "An unforgettable masterpiece!"
    reader_id: "reader-1"
    book_id: "book-2"
  }) {
    data { id rating review }
  }
}
```

## Key mAIcro Concepts Demonstrated

### Auto-Generated CRUD Operations

For each table, mAIcro automatically creates:
- `{table}Add` — Create new records
- `{table}Update` — Modify existing records
- `{table}Delete` — Remove records
- `{table}` (plural) — List records with pagination and filtering
- `{table}` (singular) — Fetch a single record by ID

### Semantic Search

The `synopsis` field in the **books** table has `has_vector: true`. This means:
- Synopses are automatically embedded into vectors (via OpenAI or local LLM)
- You can search for books by meaning: "Find stories about space exploration" instead of exact text matches
- Results are ranked by relevance

### Vector Embeddings & Full-Text Search

- **Vector embeddings** power semantic search (understand meaning)
- **Full-text search** indexes all text fields for fast keyword queries
- Both are indexed for millisecond-scale performance

### Sensitive Fields

Fields marked `is_sensitive: true`:
- `readers.password` — Encrypted and never returned to non-admin queries
- `readers.email`, `readers.my_secrets` — Redacted for regular users
- `authors.email` — Hidden from non-admins
- `books.price` — Price information protected
- `reviews.reviewer_ip` — Privacy-protected

Non-admin users see `null` for these fields. Only admins get the actual values.

### Row-Level Security with Filters

The `team_notes` table applies the `TeamIsolation` filter, ensuring that:
- Users only see notes for their team
- Admins can override the filter to see everything
- Filters are composable and reusable across tables

### Graph Sync

Every insert, update, or delete to the SQL database automatically syncs to the Apache AGE graph. This enables:
- Complex relationship queries ("Who has reviewed the same books?")
- Network analysis ("Which readers form a connected community?")
- Path-finding ("What's the shortest relationship chain between these two readers?")

## Running the Scripts

The setup is split into numbered scripts for modularity:

- **01.book_club_setup.gql** — Master orchestrator (run this!)
- **02.clear_db.gql** — Wipe existing data
- **03.platform_setup.gql** — Enable file storage, search, jobs
- **04.create_tables.gql** — Define schema, auto-generate API
- **05.graph_bootstrap.gql** — Initialize Apache AGE graph
- **06.seed_data.gql** — Load realistic test data
- **07.build_social_graph.gql** — Create reader relationship graph
- **08.verify.gql** — Test that everything works
- **10.clean_author_names.gql** — Data quality cleanup

Each script includes documentation explaining what it does and why.

## Extending the Project

Try these modifications:

1. **Add new tables** — Use `DbCreateTable` to add `discussions`, `reading_lists`, or `recommendations`
2. **New filter templates** — Create `AuthorFilter` to limit visibility by author nationality
3. **Custom operations** — Write GraphQL wrappers around business logic (e.g., "recommend 5 books similar to this one")
4. **Webhooks** — Trigger external systems when reviews are posted or new authors join
5. **Analytics** — Query the graph to identify book clubs, influential readers, or trending genres

## Next Steps

- Read the [Database Reference](/reference/database) to understand schema design patterns
- Explore [Filter Templates](/reference/filters) to build custom authorization rules
- Learn about [Vector Search](/docs/vector-search) for semantic capabilities
- Check out the [Graph Integration](/docs/graph-integration) guide for relationship queries
