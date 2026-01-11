require "../lib/cml/spec/spec_helper"

# This spec reproduces the compile-time failure:
# lib/cml/src/cml.cr:1049:36 Error: undefined constant T
# when CML.guard is defined as def self.guard(&block : -> Event(T)).

describe "CML.guard compile error" do
  it "fails to compile due to undefined constant T in guard signature" do
    # Intentionally triggers compilation of CML.guard.
    CML.guard { CML.always(0) }
  end
end
