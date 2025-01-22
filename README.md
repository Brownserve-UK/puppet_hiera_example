# Example Puppet Repository

A fully functional example repository that demonstrates how to use Hiera to build up node classifications by making use of Puppet's trusted certificate extensions.

This repository mostly exists as a way to quickly test some of our Puppet scripts/tooling however it can also be used as a template to help you quickly get started with using Puppet in your own environment.

## How it all works

When Puppet nodes request their certificates they have the option to embed additional data in the certificate signing request which then become trusted facts. (You can read more about CSR extensions in the [Puppet docs](https://puppet.com/docs/puppet/7/ssl_attributes_extensions.html))  
We take advantage of this by using `pp_service`, `pp_role` and `pp_environment` to allow us to define node roles within hiera, this in turn allows us to develop reusable modules which can quickly be deployed to a single node or the entire estate.

## Encrypting secrets with Hiera-eyaml

This repo makes use of [hiera-eyaml](https://github.com/voxpupuli/hiera-eyaml) to encrypt sensitive values within the configuration data stored in Hiera. (e.g. Passwords, certificates etc)
To be able to encrypt and decrypt these values you need a key value pair.

To generate your own:

* Ensure that you have ruby and the `bundler` gem installed for your system.
* From the root of this repository run `bundle install`
* Run `bundle exec eyaml createkeys`
* Two keys should be created in the `keys` directory, `private_key.pkcs7.pem` and `public_key.pkcs7.pem`
* Copy the values `private_key.pkcs7.pem` and `public_key.pkcs7.pem` to your Puppetserver
* Keep a copy of `private_key.pkcs7.pem` somewhere safe (like a password manager)
* Delete the `private_key.pkcs7.pem` from the `keys` directory (don't worry it is gitignored so you won't commit it by accident)

The location you need to copy the keys to depends on your values for `pkcs7_private_key` and `pkcs7_public_key` in your `hiera.yaml` file. (for this example repo that's `/etc/puppetlabs/puppet/keys`)

>⚠️ Seriously - make sure you have a copy of `private_key.pkcs7.pem` stored somewhere safe (like a password manager) that way if you ever lose your Puppetserver then you can still read your secrets!

By keeping the `public_key.pkcs7.pem` in the `keys` directory of this project you can quickly encrypt secrets for use your hiera data.
Simply run `bundle exec eyaml encrypt -s 'my_secret_value'` and paste the output into your hiera data file.
