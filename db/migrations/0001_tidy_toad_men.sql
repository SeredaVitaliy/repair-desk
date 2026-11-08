CREATE TYPE "public"."request_status" AS ENUM('new', 'in_progress', 'rejected', 'done', 'closed');--> statement-breakpoint
CREATE TYPE "public"."urgency_level" AS ENUM('normal', 'urgent');--> statement-breakpoint
CREATE TABLE "requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"address" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"urgency" "urgency_level" DEFAULT 'normal' NOT NULL,
	"status" "request_status" DEFAULT 'new' NOT NULL,
	"master_id" uuid NOT NULL,
	"author_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "requests" ADD CONSTRAINT "requests_master_id_users_id_fk" FOREIGN KEY ("master_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "requests" ADD CONSTRAINT "requests_author_id_users_id_fk" FOREIGN KEY ("author_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;