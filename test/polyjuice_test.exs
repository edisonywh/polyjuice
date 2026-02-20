defmodule Polyjuice.Test do
  use Polyjuice.DataCase

  alias Polyjuice.Repo
  alias Polyjuice.Schemas.Activity
  alias Polyjuice.Schemas.Activity.{Activated, Cancelled}

  describe "Polyjuice with Activity schema integration" do
    test "(map) stores and retrieves activated event correctly" do
      activated_map = %{
        "type" => "activated",
        "user_id" => 123,
        "activated_at" => DateTime.utc_now(),
        "activation_code" => "ACT-12345"
      }

      activity = %Activity{
        title: "User Activation",
        user_id: 123,
        event: activated_map
      }

      {:ok, saved_activity} = Repo.insert(activity)

      loaded_activity = Repo.get!(Activity, saved_activity.id)

      assert %Activated{} = loaded_activity.event
      assert loaded_activity.event.user_id == 123
      assert loaded_activity.event.activation_code == "ACT-12345"
      assert loaded_activity.event.type == "activated"
    end

    test "stores and retrieves activated event correctly" do
      activated_struct = %Activated{
        type: "activated",
        user_id: 123,
        activated_at: DateTime.utc_now(),
        activation_code: "ACT-12345"
      }

      activity = %Activity{
        title: "User Activation",
        user_id: 123,
        event: activated_struct
      }

      {:ok, saved_activity} = Repo.insert(activity)

      loaded_activity = Repo.get!(Activity, saved_activity.id)

      assert %Activated{} = loaded_activity.event
      assert loaded_activity.event.user_id == 123
      assert loaded_activity.event.activation_code == "ACT-12345"
      assert loaded_activity.event.type == "activated"
    end

    test "stores and retrieves cancelled event correctly" do
      cancelled_struct = %Cancelled{
        type: "cancelled",
        user_id: 456,
        cancelled_at: DateTime.utc_now(),
        reason: "user_request"
      }

      activity = %Activity{
        title: "User Cancellation",
        user_id: 456,
        event: cancelled_struct
      }

      {:ok, saved_activity} = Repo.insert(activity)
      loaded_activity = Repo.get!(Activity, saved_activity.id)

      assert %Cancelled{} = loaded_activity.event
      assert loaded_activity.event.user_id == 456
      assert loaded_activity.event.reason == "user_request"
      assert loaded_activity.event.type == "cancelled"
    end

    test "validates event data through changeset" do
      invalid_data = %{
        title: "Invalid Activity",
        user_id: 1,
        event: %{
          "type" => "activated",
          # Invalid type
          "user_id" => "not_an_integer",
          "activated_at" => DateTime.utc_now()
        }
      }

      changeset = Activity.changeset(%Activity{}, invalid_data)

      refute changeset.valid?
      assert changeset.errors[:event]
    end

    test "validates cancelled event with invalid reason" do
      invalid_data = %{
        title: "Invalid Cancellation",
        user_id: 123,
        event: %Cancelled{
          type: "cancelled",
          user_id: 123,
          cancelled_at: DateTime.utc_now(),
          # Not in allowed values
          reason: "invalid_reason"
        }
      }

      changeset = Activity.changeset(%Activity{}, invalid_data)
      refute changeset.valid?
      assert changeset.errors[:event]
    end

    test "validates map-based event data through cast_embed" do
      invalid_map_data = %{
        title: "Map Validation Test",
        user_id: 456,
        event: %{
          "type" => "cancelled",
          "user_id" => 456,
          "cancelled_at" => DateTime.utc_now(),
          # Not in allowed values
          "reason" => "invalid_reason"
        }
      }

      changeset = Activity.changeset(%Activity{}, invalid_map_data)
      refute changeset.valid?
      assert changeset.errors[:event]
      assert changeset.errors[:event] == {"reason is invalid", []}
    end

    test "validates valid event data through cast_embed" do
      valid_map_data = %{
        title: "Valid Map Test",
        user_id: 789,
        event: %{
          "type" => "cancelled",
          "user_id" => 789,
          "cancelled_at" => DateTime.utc_now(),
          # Valid reason
          "reason" => "user_request"
        }
      }

      changeset = Activity.changeset(%Activity{}, valid_map_data)
      assert changeset.valid?
      assert changeset.changes[:event]
      assert %Cancelled{} = changeset.changes[:event]
    end

    test "handles completely wrong embedded schema type" do
      alias Polyjuice.Schemas.Activity.OtherSchema

      wrong_schema_data = %{
        title: "Completely Wrong Schema",
        user_id: 888,
        event: %OtherSchema{
          name: "some name",
          value: 42
        }
      }

      changeset = Activity.changeset(%Activity{}, wrong_schema_data)

      refute changeset.valid?

      assert changeset.errors[:event] ==
               {"invalid polyjuice schema type Polyjuice.Schemas.Activity.OtherSchema", []}
    end

    test "rejects activity with missing event" do
      changeset = Activity.changeset(%Activity{}, %{title: "No Event", user_id: 1})
      refute changeset.valid?
      assert changeset.errors[:event] == {"can't be blank", [validation: :required]}
    end

    test "handles event with unknown type gracefully" do
      invalid_data = %{
        title: "Unknown Event",
        user_id: 123,
        event: %{
          "type" => "unknown_event",
          "data" => "test"
        }
      }

      changeset = Activity.changeset(%Activity{}, invalid_data)
      refute changeset.valid?
      assert changeset.errors[:event] == {"unknown type \"unknown_event\"", []}
    end
  end

  describe "round-trip data integrity" do
    test "complex activated event survives database round-trip" do
      complex_struct = %Activated{
        type: "activated",
        user_id: 999,
        activated_at: ~U[2024-01-15 12:30:45Z],
        activation_code: "COMPLEX-999-XYZ"
      }

      activity = %Activity{
        title: "Complex Activation",
        user_id: 999,
        event: complex_struct
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert loaded.event.user_id == 999
      assert loaded.event.activation_code == "COMPLEX-999-XYZ"
      # SQLite stores datetime as string, so we compare the string representation
      assert loaded.event.activated_at == "2024-01-15T12:30:45Z"
    end

    test "string values are preserved correctly" do
      cancelled_struct = %Cancelled{
        type: "cancelled",
        user_id: 777,
        cancelled_at: DateTime.utc_now(),
        reason: "payment_failed"
      }

      activity = %Activity{
        title: "String Test",
        user_id: 777,
        event: cancelled_struct
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert loaded.event.reason == "payment_failed"
    end

    test "nil optional values are handled correctly" do
      activated_struct = %Activated{
        type: "activated",
        user_id: 555,
        activated_at: DateTime.utc_now()
        # No activation_code - should be nil
      }

      activity = %Activity{
        title: "Nil Test",
        user_id: 555,
        event: activated_struct
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert loaded.event.activation_code == nil
    end
  end

  describe "edge cases and error handling" do
    test "handles type coercion gracefully" do
      activated_struct = %Activated{
        type: "activated",
        user_id: 888,
        activated_at: DateTime.utc_now(),
        activation_code: "COERCION-TEST"
      }

      activity = %Activity{
        title: "Type Coercion",
        user_id: 888,
        event: activated_struct
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert loaded.event.user_id == 888
    end

    test "handles updates to polymorphic event field" do
      activity = %Activity{
        title: "Update Test",
        user_id: 333,
        event: %Activated{
          type: "activated",
          user_id: 333,
          activated_at: DateTime.utc_now(),
          activation_code: "ORIGINAL"
        }
      }

      {:ok, saved} = Repo.insert(activity)

      changeset =
        Activity.changeset(saved, %{
          event: %Cancelled{
            type: "cancelled",
            user_id: 333,
            cancelled_at: DateTime.utc_now(),
            reason: "user_request"
          }
        })

      {:ok, updated} = Repo.update(changeset)
      loaded = Repo.get!(Activity, updated.id)

      assert %Cancelled{} = loaded.event
      assert loaded.event.reason == "user_request"
    end

    test "validates user_id consistency between activity and event" do
      activity = %Activity{
        title: "Consistency Test",
        user_id: 111,
        event: %Activated{
          type: "activated",
          # Different from activity user_id
          user_id: 999,
          activated_at: DateTime.utc_now()
        }
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      # The event should maintain its own user_id
      assert loaded.event.user_id == 999
    end
  end

  describe "polymorphic behavior with different event types" do
    test "multiple activities with different event types work independently" do
      activated_activity = %Activity{
        title: "Activated Event",
        user_id: 100,
        event: %Activated{
          type: "activated",
          user_id: 100,
          activated_at: DateTime.utc_now(),
          activation_code: "ACT-100"
        }
      }

      cancelled_activity = %Activity{
        title: "Cancelled Event",
        user_id: 200,
        event: %Cancelled{
          type: "cancelled",
          user_id: 200,
          cancelled_at: DateTime.utc_now(),
          reason: "payment_failed"
        }
      }

      {:ok, saved_activated} = Repo.insert(activated_activity)
      {:ok, saved_cancelled} = Repo.insert(cancelled_activity)

      # Load and verify both
      loaded_activated = Repo.get!(Activity, saved_activated.id)
      loaded_cancelled = Repo.get!(Activity, saved_cancelled.id)

      assert %Activated{} = loaded_activated.event
      assert loaded_activated.event.activation_code == "ACT-100"

      assert %Cancelled{} = loaded_cancelled.event
      assert loaded_cancelled.event.reason == "payment_failed"
    end
  end

  describe "raw map support" do
    test "accepts maps with string keys directly" do
      map_event = %{
        "type" => "activated",
        "user_id" => 456,
        "activated_at" => DateTime.utc_now(),
        "activation_code" => "STRING-456"
      }

      activity = %Activity{
        title: "String Keys Test",
        user_id: 456,
        event: map_event
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert %Activated{} = loaded.event
      assert loaded.event.user_id == 456
      assert loaded.event.activation_code == "STRING-456"
      assert loaded.event.type == "activated"
    end

    test "accepts maps with atom keys directly" do
      map_event = %{
        type: :activated,
        user_id: 789,
        activated_at: DateTime.utc_now(),
        activation_code: "ATOM-789"
      }

      activity = %Activity{
        title: "Atom Keys Test",
        user_id: 789,
        event: map_event
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert %Activated{} = loaded.event
      assert loaded.event.user_id == 789
      assert loaded.event.activation_code == "ATOM-789"
    end

    test "works with changeset validation" do
      attrs = %{
        "title" => "Factory Test",
        "user_id" => 321,
        "event" => %{
          "type" => "cancelled",
          "user_id" => 321,
          "cancelled_at" => DateTime.utc_now(),
          "reason" => "user_request"
        }
      }

      changeset = Activity.changeset(%Activity{}, attrs)
      assert changeset.valid?
      {:ok, activity} = Repo.insert(changeset)
      assert %Cancelled{} = activity.event
      assert activity.event.reason == "user_request"
    end

    test "handles mixed struct and map usage" do
      # First activity with struct
      struct_activity = %Activity{
        title: "Struct Event",
        user_id: 111,
        event: %Activated{
          type: "activated",
          user_id: 111,
          activated_at: DateTime.utc_now(),
          activation_code: "STRUCT-111"
        }
      }

      # Second activity with map
      map_activity = %Activity{
        title: "Map Event",
        user_id: 222,
        event: %{
          "type" => "activated",
          "user_id" => 222,
          "activated_at" => DateTime.utc_now(),
          "activation_code" => "MAP-222"
        }
      }

      {:ok, saved_struct} = Repo.insert(struct_activity)
      {:ok, saved_map} = Repo.insert(map_activity)

      loaded_struct = Repo.get!(Activity, saved_struct.id)
      loaded_map = Repo.get!(Activity, saved_map.id)

      assert %Activated{} = loaded_struct.event
      assert loaded_struct.event.activation_code == "STRUCT-111"

      assert %Activated{} = loaded_map.event
      assert loaded_map.event.activation_code == "MAP-222"
    end

    test "rejects map with missing type field (via changeset)" do
      invalid_attrs = %{
        "title" => "Missing Type",
        "user_id" => 999,
        "event" => %{
          "user_id" => 999,
          "activated_at" => DateTime.utc_now()
        }
      }

      changeset = Activity.changeset(%Activity{}, invalid_attrs)
      refute changeset.valid?
      assert changeset.errors[:event] == {"no type field found", []}
    end

    test "rejects map with unknown type value (via changeset)" do
      invalid_attrs = %{
        "title" => "Unknown Type",
        "user_id" => 888,
        "event" => %{
          "type" => "unknown_event_type",
          "user_id" => 888,
          "data" => "test"
        }
      }

      changeset = Activity.changeset(%Activity{}, invalid_attrs)
      refute changeset.valid?
      assert changeset.errors[:event] == {"unknown type \"unknown_event_type\"", []}
    end

    test "validates map data through embedded schema changeset" do
      invalid_attrs = %{
        "title" => "Invalid Data",
        "user_id" => 1,
        "event" => %{
          "type" => "activated",
          # Invalid - should be integer
          "user_id" => "not_an_integer",
          "activated_at" => DateTime.utc_now()
        }
      }

      changeset = Activity.changeset(%Activity{}, invalid_attrs)
      refute changeset.valid?
      assert changeset.errors[:event]
    end

    test "database round-trip preserves map-based data correctly" do
      map_event = %{
        "type" => "cancelled",
        "user_id" => 555,
        "cancelled_at" => DateTime.utc_now(),
        "reason" => "payment_failed"
      }

      activity = %Activity{
        title: "Round Trip Test",
        user_id: 555,
        event: map_event
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      # Should be converted to struct after load
      assert %Cancelled{} = loaded.event
      assert loaded.event.user_id == 555
      assert loaded.event.reason == "payment_failed"
      assert loaded.event.type == "cancelled"

      # Should be able to update it
      updated_changeset =
        Activity.changeset(loaded, %{
          title: "Updated Round Trip"
        })

      {:ok, updated} = Repo.update(updated_changeset)
      reloaded = Repo.get!(Activity, updated.id)

      # Event should still be intact
      assert %Cancelled{} = reloaded.event
      assert reloaded.event.user_id == 555
      assert reloaded.event.reason == "payment_failed"
      assert reloaded.title == "Updated Round Trip"
    end

    test "map with string type works with changeset" do
      attrs = %{
        "title" => "String Type Test",
        "user_id" => 654,
        "event" => %{
          "type" => "activated",
          "user_id" => 654,
          "activated_at" => DateTime.utc_now(),
          "activation_code" => "STRING-654"
        }
      }

      changeset = Activity.changeset(%Activity{}, attrs)
      assert changeset.valid?

      {:ok, activity} = Repo.insert(changeset)
      assert %Activated{} = activity.event
      assert activity.event.activation_code == "STRING-654"
    end

    test "map with atom type works with changeset" do
      attrs = %{
        title: "Atom Type Test",
        user_id: 987,
        event: %{
          type: :cancelled,
          user_id: 987,
          cancelled_at: DateTime.utc_now(),
          reason: "fraud_detected"
        }
      }

      changeset = Activity.changeset(%Activity{}, attrs)
      assert changeset.valid?

      {:ok, activity} = Repo.insert(changeset)
      assert %Cancelled{} = activity.event
      assert activity.event.reason == "fraud_detected"
    end
  end

  describe "direct insertion without changeset validation" do
    test "direct struct insertion bypasses validation" do
      # Direct insertion skips changeset validation
      activity = %Activity{
        title: "Direct Struct Insert",
        user_id: 555,
        event: %Activated{
          type: "activated",
          user_id: 555,
          activated_at: DateTime.utc_now(),
          activation_code: "DIRECT-555"
        }
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert %Activated{} = loaded.event
      assert loaded.event.user_id == 555
      assert loaded.event.activation_code == "DIRECT-555"
    end

    test "direct map insertion bypasses validation" do
      # Direct map insertion works but skips validation
      activity = %Activity{
        title: "Direct Map Insert",
        user_id: 666,
        event: %{
          "type" => "cancelled",
          "user_id" => 666,
          "cancelled_at" => DateTime.utc_now(),
          "reason" => "payment_failed"
        }
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      # Map is stored and loaded as struct
      assert %Cancelled{} = loaded.event
      assert loaded.event.user_id == 666
      assert loaded.event.reason == "payment_failed"
    end

    test "Repo.insert! also bypasses validation" do
      activity = %Activity{
        title: "Insert Bang",
        user_id: 777,
        event: %Activated{
          type: "activated",
          user_id: 777,
          activated_at: DateTime.utc_now(),
          activation_code: "BANG-777"
        }
      }

      saved = Repo.insert!(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert %Activated{} = loaded.event
      assert loaded.event.activation_code == "BANG-777"
    end
  end

  describe "schema evolution and backward compatibility" do
    test "loads record with extra fields from database" do
      activated_activity = %Activity{
        title: "Evolution Test",
        user_id: 100,
        event: %Activated{
          type: "activated",
          user_id: 100,
          activated_at: DateTime.utc_now(),
          activation_code: "EVOLUTION-TEST"
        }
      }

      {:ok, saved} = Repo.insert(activated_activity)

      # Simulate database having extra fields by directly updating the JSON
      # This simulates what would happen if the schema had more fields in the past
      extra_data = %{
        "type" => "activated",
        "user_id" => 100,
        "activated_at" => "2024-01-15T12:30:45Z",
        "activation_code" => "EVOLUTION-TEST",
        "extra_field" => "this field doesn't exist in current schema",
        "deprecated_flag" => true,
        "old_metadata" => %{"version" => "1.0", "legacy" => true}
      }

      Repo.query!(
        "UPDATE activities SET event = ? WHERE id = ?",
        [Jason.encode!(extra_data), saved.id]
      )

      loaded = Repo.get!(Activity, saved.id)

      # Should load successfully despite extra fields
      assert %Activated{} = loaded.event
      assert loaded.event.type == "activated"
      assert loaded.event.user_id == 100
      assert loaded.event.activation_code == "EVOLUTION-TEST"

      # Extra fields should be ignored (not cause errors)
      # The struct should only contain the defined fields
      refute Map.has_key?(loaded.event, :extra_field)
      refute Map.has_key?(loaded.event, :deprecated_flag)
      refute Map.has_key?(loaded.event, :old_metadata)
    end

    test "loads record with missing fields from database" do
      activated_activity = %Activity{
        title: "Missing Fields Test",
        user_id: 200,
        event: %Activated{
          type: "activated",
          user_id: 200,
          activated_at: DateTime.utc_now(),
          activation_code: "WILL-BE-REMOVED"
        }
      }

      {:ok, saved} = Repo.insert(activated_activity)

      # Now simulate old database record with missing optional field
      minimal_data = %{
        "type" => "activated",
        "user_id" => 200,
        "activated_at" => "2024-01-15T12:30:45Z"
        # Missing activation_code field
      }

      # Update with minimal data (missing activation_code)
      Repo.query!(
        "UPDATE activities SET event = ? WHERE id = ?",
        [Jason.encode!(minimal_data), saved.id]
      )

      # Load it back
      loaded = Repo.get!(Activity, saved.id)

      # Should load successfully with nil for missing optional fields
      assert %Activated{} = loaded.event
      assert loaded.event.type == "activated"
      assert loaded.event.user_id == 200
      # Missing field becomes nil
      assert loaded.event.activation_code == nil
    end
  end
end
