-- Google Sign-In replaces phone + OTP (SMS costs money; Google sign-in is free).
-- google_sub is Google's permanent id for the account ("sub" claim); email can change, sub never does.
-- Vendors are matched by the email the admin registers for their stall; on first sign-in google_sub is linked.
ALTER TABLE users ADD COLUMN google_sub VARCHAR(64) NULL UNIQUE AFTER email;
