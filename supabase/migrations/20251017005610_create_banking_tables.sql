/*
  # Zenith Premium Bank - Database Schema

  ## Overview
  This migration creates the core banking database schema for Zenith Premium Bank,
  including user accounts, transactions, and service management.

  ## New Tables

  ### `bank_accounts`
  - `id` (uuid, primary key) - Unique account identifier
  - `user_id` (uuid, references auth.users) - Account owner
  - `account_number` (text, unique) - 12-digit account number
  - `account_type` (text) - Type: 'savings', 'checking', 'premium', 'wealth'
  - `balance` (numeric) - Current account balance
  - `currency` (text) - Currency code (default: USD)
  - `status` (text) - Status: 'active', 'inactive', 'suspended'
  - `created_at` (timestamptz) - Account creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp

  ### `transactions`
  - `id` (uuid, primary key) - Unique transaction identifier
  - `account_id` (uuid, references bank_accounts) - Associated account
  - `transaction_type` (text) - Type: 'deposit', 'withdrawal', 'transfer'
  - `amount` (numeric) - Transaction amount
  - `description` (text) - Transaction description
  - `reference_number` (text, unique) - Transaction reference
  - `status` (text) - Status: 'pending', 'completed', 'failed'
  - `created_at` (timestamptz) - Transaction timestamp

  ### `user_profiles`
  - `id` (uuid, primary key) - Profile identifier
  - `user_id` (uuid, references auth.users) - Associated user
  - `full_name` (text) - User's full name
  - `phone` (text) - Phone number
  - `address` (text) - Physical address
  - `kyc_verified` (boolean) - KYC verification status
  - `created_at` (timestamptz) - Profile creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp

  ## Security
  - Row Level Security (RLS) enabled on all tables
  - Users can only access their own data
  - Strict authentication requirements for all operations
*/

CREATE TABLE IF NOT EXISTS bank_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  account_number text UNIQUE NOT NULL,
  account_type text NOT NULL DEFAULT 'checking',
  balance numeric(15, 2) NOT NULL DEFAULT 0.00,
  currency text NOT NULL DEFAULT 'USD',
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_account_type CHECK (account_type IN ('savings', 'checking', 'premium', 'wealth')),
  CONSTRAINT valid_status CHECK (status IN ('active', 'inactive', 'suspended')),
  CONSTRAINT positive_balance CHECK (balance >= 0)
);

CREATE TABLE IF NOT EXISTS transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid REFERENCES bank_accounts(id) ON DELETE CASCADE,
  transaction_type text NOT NULL,
  amount numeric(15, 2) NOT NULL,
  description text DEFAULT '',
  reference_number text UNIQUE NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  CONSTRAINT valid_transaction_type CHECK (transaction_type IN ('deposit', 'withdrawal', 'transfer')),
  CONSTRAINT valid_transaction_status CHECK (status IN ('pending', 'completed', 'failed')),
  CONSTRAINT positive_amount CHECK (amount > 0)
);

CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  full_name text NOT NULL DEFAULT '',
  phone text DEFAULT '',
  address text DEFAULT '',
  kyc_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own accounts"
  ON bank_accounts FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own accounts"
  ON bank_accounts FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own accounts"
  ON bank_accounts FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own transactions"
  ON transactions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM bank_accounts
      WHERE bank_accounts.id = transactions.account_id
      AND bank_accounts.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create transactions for own accounts"
  ON transactions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM bank_accounts
      WHERE bank_accounts.id = transactions.account_id
      AND bank_accounts.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view own profile"
  ON user_profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own profile"
  ON user_profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON user_profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_bank_accounts_user_id ON bank_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
