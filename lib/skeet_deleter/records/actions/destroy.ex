defmodule SkeetDeleter.Records.Post.Destroy do
  use Ash.Resource.ManualDestroy

  def destroy(_changeset, _opts, %{actor: _actor, tenant: _tenant}) do
  end
end
