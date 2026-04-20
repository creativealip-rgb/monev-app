CREATE TABLE `mobile_refresh_tokens` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`user_id` integer NOT NULL,
	`token_hash` text NOT NULL,
	`expires_at` integer NOT NULL,
	`revoked_at` integer,
	`replaced_by_token_hash` text,
	`device_info` text,
	`ip_address` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `mobile_refresh_tokens_token_hash_unique` ON `mobile_refresh_tokens` (`token_hash`);--> statement-breakpoint
CREATE INDEX `idx_mobile_refresh_tokens_user_id` ON `mobile_refresh_tokens` (`user_id`);--> statement-breakpoint
CREATE INDEX `idx_mobile_refresh_tokens_expires_at` ON `mobile_refresh_tokens` (`expires_at`);