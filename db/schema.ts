import { pgTable, uuid, text, timestamp, pgEnum } from "drizzle-orm/pg-core";

export const requestStatus = pgEnum("request_status", [
  "new",
  "in_progress",
  "rejected",
  "done",
  "closed",
]);

export const urgencyLevel = pgEnum("urgency_level", ["normal", "urgent"]);

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: text("email").notNull().unique(),
  fullName: text("full_name").notNull().default(""),
  role: text("role").notNull().default("master"),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});

export const requests = pgTable("requests", {
  id: uuid("id").primaryKey().defaultRandom(),
  address: text("address").notNull(),
  description: text("description").notNull().default(""),
  urgency: urgencyLevel("urgency").notNull().default("normal"),
  status: requestStatus("status").notNull().default("new"),
  masterId: uuid("master_id")
    .notNull()
    .references(() => users.id),
  authorId: uuid("author_id")
    .notNull()
    .references(() => users.id),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});
