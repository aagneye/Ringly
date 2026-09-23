CREATE TYPE "public"."action_source" AS ENUM('memo', 'nightly_review', 'manual', 'question');--> statement-breakpoint
CREATE TYPE "public"."action_status" AS ENUM('applied', 'awaiting_approval', 'approved', 'rejected', 'failed');--> statement-breakpoint
CREATE TYPE "public"."deal_stage" AS ENUM('new', 'contacted', 'proposal', 'negotiation', 'won', 'lost');--> statement-breakpoint
CREATE TYPE "public"."draft_status" AS ENUM('draft', 'approved', 'sent', 'discarded');--> statement-breakpoint
CREATE TYPE "public"."reminder_status" AS ENUM('pending', 'done', 'dismissed');--> statement-breakpoint
CREATE TYPE "public"."sentiment" AS ENUM('positive', 'neutral', 'negative');--> statement-breakpoint
CREATE TABLE "contacts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"normalised_name" text NOT NULL,
	"company" text,
	"normalised_company" text,
	"email" text,
	"phone" text,
	"role" text,
	"summary" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "deals" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"contact_id" uuid NOT NULL,
	"title" text NOT NULL,
	"stage" "deal_stage" DEFAULT 'new' NOT NULL,
	"next_action" text,
	"deadline" timestamp with time zone,
	"budget" text,
	"concerns" text,
	"sentiment" "sentiment" DEFAULT 'neutral',
	"health_score" integer,
	"last_contact_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"deal_id" uuid,
	"contact_id" uuid,
	"raw_transcript" text NOT NULL,
	"gist" text,
	"structured" jsonb,
	"duration_seconds" integer,
	"source" text DEFAULT 'voice' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "drafts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"deal_id" uuid NOT NULL,
	"subject" text NOT NULL,
	"body" text NOT NULL,
	"status" "draft_status" DEFAULT 'draft' NOT NULL,
	"reasoning" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "reminders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"deal_id" uuid NOT NULL,
	"message" text NOT NULL,
	"due_at" timestamp with time zone NOT NULL,
	"status" "reminder_status" DEFAULT 'pending' NOT NULL,
	"created_by" "action_source" DEFAULT 'memo' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"completed_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"deal_id" uuid NOT NULL,
	"title" text NOT NULL,
	"starts_at" timestamp with time zone NOT NULL,
	"ends_at" timestamp with time zone NOT NULL,
	"location" text,
	"notes" text,
	"created_by" "action_source" DEFAULT 'memo' NOT NULL,
	"acknowledged" boolean DEFAULT false NOT NULL,
	"external_ref" text,
	"exported_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "agent_actions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"run_id" uuid NOT NULL,
	"note_id" uuid,
	"deal_id" uuid,
	"tool" text NOT NULL,
	"args" jsonb,
	"status" "action_status" NOT NULL,
	"source" "action_source" NOT NULL,
	"summary" text NOT NULL,
	"reasoning" text,
	"error" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"resolved_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "model_traces" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"run_id" uuid NOT NULL,
	"task" text NOT NULL,
	"tier" text NOT NULL,
	"model" text NOT NULL,
	"prompt_tokens" integer DEFAULT 0 NOT NULL,
	"completion_tokens" integer DEFAULT 0 NOT NULL,
	"latency_ms" integer DEFAULT 0 NOT NULL,
	"failed" boolean DEFAULT false NOT NULL,
	"error" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "company_facts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"contact_id" uuid NOT NULL,
	"company" text NOT NULL,
	"fact" text NOT NULL,
	"source_url" text NOT NULL,
	"source_title" text,
	"fetched_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "briefings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"for_date" date NOT NULL,
	"headline" text NOT NULL,
	"spoken_text" text NOT NULL,
	"items" jsonb NOT NULL,
	"run_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "deals" ADD CONSTRAINT "deals_contact_id_contacts_id_fk" FOREIGN KEY ("contact_id") REFERENCES "public"."contacts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notes" ADD CONSTRAINT "notes_deal_id_deals_id_fk" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notes" ADD CONSTRAINT "notes_contact_id_contacts_id_fk" FOREIGN KEY ("contact_id") REFERENCES "public"."contacts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "drafts" ADD CONSTRAINT "drafts_deal_id_deals_id_fk" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "reminders" ADD CONSTRAINT "reminders_deal_id_deals_id_fk" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "events" ADD CONSTRAINT "events_deal_id_deals_id_fk" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "agent_actions" ADD CONSTRAINT "agent_actions_note_id_notes_id_fk" FOREIGN KEY ("note_id") REFERENCES "public"."notes"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "agent_actions" ADD CONSTRAINT "agent_actions_deal_id_deals_id_fk" FOREIGN KEY ("deal_id") REFERENCES "public"."deals"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "company_facts" ADD CONSTRAINT "company_facts_contact_id_contacts_id_fk" FOREIGN KEY ("contact_id") REFERENCES "public"."contacts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "contacts_normalised_name_idx" ON "contacts" USING btree ("normalised_name");--> statement-breakpoint
CREATE INDEX "contacts_normalised_company_idx" ON "contacts" USING btree ("normalised_company");--> statement-breakpoint
CREATE INDEX "deals_contact_id_idx" ON "deals" USING btree ("contact_id");--> statement-breakpoint
CREATE INDEX "deals_stage_idx" ON "deals" USING btree ("stage");--> statement-breakpoint
CREATE INDEX "deals_last_contact_at_idx" ON "deals" USING btree ("last_contact_at");--> statement-breakpoint
CREATE INDEX "notes_deal_id_idx" ON "notes" USING btree ("deal_id");--> statement-breakpoint
CREATE INDEX "notes_contact_id_idx" ON "notes" USING btree ("contact_id");--> statement-breakpoint
CREATE INDEX "notes_created_at_idx" ON "notes" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "drafts_deal_id_idx" ON "drafts" USING btree ("deal_id");--> statement-breakpoint
CREATE INDEX "drafts_status_idx" ON "drafts" USING btree ("status");--> statement-breakpoint
CREATE INDEX "reminders_deal_id_idx" ON "reminders" USING btree ("deal_id");--> statement-breakpoint
CREATE INDEX "reminders_due_at_idx" ON "reminders" USING btree ("due_at");--> statement-breakpoint
CREATE INDEX "reminders_status_idx" ON "reminders" USING btree ("status");--> statement-breakpoint
CREATE INDEX "events_deal_id_idx" ON "events" USING btree ("deal_id");--> statement-breakpoint
CREATE INDEX "events_starts_at_idx" ON "events" USING btree ("starts_at");--> statement-breakpoint
CREATE INDEX "agent_actions_run_id_idx" ON "agent_actions" USING btree ("run_id");--> statement-breakpoint
CREATE INDEX "agent_actions_deal_id_idx" ON "agent_actions" USING btree ("deal_id");--> statement-breakpoint
CREATE INDEX "agent_actions_status_idx" ON "agent_actions" USING btree ("status");--> statement-breakpoint
CREATE INDEX "agent_actions_created_at_idx" ON "agent_actions" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "model_traces_run_id_idx" ON "model_traces" USING btree ("run_id");--> statement-breakpoint
CREATE INDEX "model_traces_tier_idx" ON "model_traces" USING btree ("tier");--> statement-breakpoint
CREATE INDEX "model_traces_created_at_idx" ON "model_traces" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "company_facts_contact_id_idx" ON "company_facts" USING btree ("contact_id");--> statement-breakpoint
CREATE INDEX "company_facts_company_idx" ON "company_facts" USING btree ("company");--> statement-breakpoint
CREATE INDEX "briefings_for_date_idx" ON "briefings" USING btree ("for_date");