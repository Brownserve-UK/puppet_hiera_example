# @summary
#   Defined type for an r10k source
type Puppetserver::R10k_source = Struct[{
  source_name => String,
  remote_path => String,
}]
