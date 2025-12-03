defmodule PolyjuiceTest do
  use ExUnit.Case
  alias PolyjuiceTest.Repo
  alias PolyjuiceTest.Schemas.Activity
  alias PolyjuiceTest.Schemas.Activity.{Activated, Cancelled}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "Polyjuice with Activity schema integration" do
    test "stores and retrieves activated event correctly" do
      activated_data = %{
        "type" => "activated",
        "user_id" => 123,
        "activated_at" => DateTime.utc_now(),
        "activation_code" => "ACT-12345"
      }

      activity = %Activity{
        title: "User Activation",
        user_id: 123,
        event: activated_data
      }

      {:ok, saved_activity} = Repo.insert(activity)

      # Retrieve from database
      loaded_activity = Repo.get!(Activity, saved_activity.id)

      # Verify the event was cast to Activated struct
      assert %Activated{} = loaded_activity.event
      assert loaded_activity.event.user_id == 123
      assert loaded_activity.event.activation_code == "ACT-12345"
      assert loaded_activity.event.type == "activated"
      assert loaded_activity.title == "User Activation"
    end

    test "stores and retrieves cancelled event correctly" do
      cancelled_data = %{
        "type" => "cancelled",
        "user_id" => 456,
        "cancelled_at" => DateTime.utc_now(),
        "reason" => "user_request",
        "refund_amount" => Decimal.new("99.99")
      }

      activity = %Activity{
        title: "Subscription Cancelled",
        user_id: 456,
        event: cancelled_data
      }

      {:ok, saved_activity} = Repo.insert(activity)
      loaded_activity = Repo.get!(Activity, saved_activity.id)

      assert %Cancelled{} = loaded_activity.event
      assert loaded_activity.event.user_id == 456
      assert loaded_activity.event.reason == "user_request"
      assert loaded_activity.event.type == "cancelled"
      assert Decimal.equal?(loaded_activity.event.refund_amount, Decimal.new("99.99"))
    end

    test "handles Activated struct input correctly" do
      activated_struct = %Activated{
        user_id: 789,
        activated_at: DateTime.utc_now(),
        activation_code: "STRUCT-789",
        type: "activated"
      }

      activity = %Activity{
        title: "Direct Struct Input",
        user_id: 789,
        event: activated_struct
      }

      {:ok, saved_activity} = Repo.insert(activity)
      loaded_activity = Repo.get!(Activity, saved_activity.id)

      assert %Activated{} = loaded_activity.event
      assert loaded_activity.event.user_id == 789
      assert loaded_activity.event.activation_code == "STRUCT-789"
    end

    test "validates event data through changeset" do
      invalid_activated = %{
        "type" => "activated",
        # Missing required user_id and activated_at
        "activation_code" => "INVALID"
      }

      changeset =
        Activity.changeset(%Activity{}, %{
          title: "Invalid Activity",
          user_id: 1,
          event: invalid_activated
        })

      assert {:error, changeset} = Repo.insert(changeset)
      assert changeset.changes.event.errors[:user_id]
      assert changeset.changes.event.errors[:activated_at]
    end

    test "validates cancelled event with invalid reason" do
      invalid_cancelled = %{
        "type" => "cancelled",
        "user_id" => 123,
        "cancelled_at" => DateTime.utc_now(),
        "reason" => "invalid_reason"
      }

      changeset =
        Activity.changeset(%Activity{}, %{
          title: "Invalid Cancellation",
          user_id: 123,
          event: invalid_cancelled
        })

      assert {:error, changeset} = Repo.insert(changeset)
      assert changeset.changes.event.errors[:reason]
    end

    test "rejects activity with missing event" do
      changeset =
        Activity.changeset(%Activity{}, %{
          title: "No Event Activity",
          user_id: 1
        })

      assert {:error, changeset} = Repo.insert(changeset)
      assert changeset.errors[:event]
    end

    test "handles event with unknown type gracefully" do
      unknown_event = %{
        "type" => "unknown_event",
        "data" => "test"
      }

      activity = %Activity{
        title: "Unknown Event",
        user_id: 1,
        event: unknown_event
      }

      assert_raise ArgumentError, fn ->
        Repo.insert(activity)
      end
    end
  end

  describe "round-trip data integrity" do
    test "complex activated event survives database round-trip" do
      complex_activated = %{
        "type" => "activated",
        "user_id" => 999,
        "activated_at" => ~U[2024-01-15 12:30:45Z],
        "activation_code" => "COMPLEX-999-XYZ"
      }

      activity = %Activity{
        title: "Complex Activation Event",
        user_id: 999,
        event: complex_activated
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert loaded.event.user_id == 999
      assert loaded.event.activation_code == "COMPLEX-999-XYZ"
      assert DateTime.compare(loaded.event.activated_at, ~U[2024-01-15 12:30:45Z]) == :eq
    end

    test "decimal values are preserved correctly" do
      cancelled_with_decimal = %{
        "type" => "cancelled",
        "user_id" => 777,
        "cancelled_at" => DateTime.utc_now(),
        "reason" => "payment_failed",
        "refund_amount" => "123.456789"
      }

      activity = %Activity{
        title: "Decimal Precision Test",
        user_id: 777,
        event: cancelled_with_decimal
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert Decimal.equal?(loaded.event.refund_amount, Decimal.new("123.456789"))
    end

    test "nil optional values are handled correctly" do
      minimal_activated = %{
        "type" => "activated",
        "user_id" => 555,
        "activated_at" => DateTime.utc_now()
        # activation_code is optional and not provided
      }

      activity = %Activity{
        title: "Minimal Event",
        user_id: 555,
        event: minimal_activated
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert loaded.event.user_id == 555
      assert loaded.event.activation_code == nil
    end
  end

  describe "edge cases and error handling" do
    test "handles type coercion gracefully" do
      # User_id as string should be converted to integer
      data_with_string_id = %{
        "type" => "activated",
        "user_id" => "888",
        "activated_at" => DateTime.utc_now(),
        "activation_code" => "COERCION-TEST"
      }

      activity = %Activity{
        title: "Coercion Test",
        user_id: 888,
        event: data_with_string_id
      }

      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert loaded.event.user_id == 888
      assert is_integer(loaded.event.user_id)
    end

    test "handles updates to polymorphic event field" do
      # Start with activated event
      activated_data = %{
        "type" => "activated",
        "user_id" => 333,
        "activated_at" => DateTime.utc_now(),
        "activation_code" => "ORIGINAL"
      }

      activity = %Activity{
        title: "Changeable Activity",
        user_id: 333,
        event: activated_data
      }

      {:ok, saved} = Repo.insert(activity)

      # Update to cancelled event
      cancelled_data = %{
        "type" => "cancelled",
        "user_id" => 333,
        "cancelled_at" => DateTime.utc_now(),
        "reason" => "user_request"
      }

      changeset = Activity.changeset(saved, %{event: cancelled_data})
      {:ok, updated} = Repo.update(changeset)

      # Verify the event type changed
      loaded = Repo.get!(Activity, updated.id)
      assert %Cancelled{} = loaded.event
      assert loaded.event.type == "cancelled"
      assert loaded.event.reason == "user_request"
    end

    test "validates user_id consistency between activity and event" do
      # Different user_ids between activity and event
      activated_data = %{
        "type" => "activated",
        # Different from activity user_id
        "user_id" => 999,
        "activated_at" => DateTime.utc_now()
      }

      activity = %Activity{
        title: "Inconsistent User ID",
        # Different from event user_id
        user_id: 111,
        event: activated_data
      }

      # This should still work - the library doesn't enforce consistency
      # That would be business logic validation
      {:ok, saved} = Repo.insert(activity)
      loaded = Repo.get!(Activity, saved.id)

      assert loaded.user_id == 111
      assert loaded.event.user_id == 999
    end
  end



  describe "polymorphic behavior with different event types" do
    test "multiple activities with different event types work independently" do
      # Create activated activity
      activated_data = %{
        "type" => "activated",
        "user_id" => 100,
        "activated_at" => DateTime.utc_now(),
        "activation_code" => "ACT-100"
      }

      activated_activity = %Activity{
        title: "User Activated",
        user_id: 100,
        event: activated_data
      }

      # Create cancelled activity
      cancelled_data = %{
        "type" => "cancelled",
        "user_id" => 200,
        "cancelled_at" => DateTime.utc_now(),
        "reason" => "fraud_detected"
      }

      cancelled_activity = %Activity{
        title: "Subscription Cancelled",
        user_id: 200,
        event: cancelled_data
      }

      # Insert both
      {:ok, saved_activated} = Repo.insert(activated_activity)
      {:ok, saved_cancelled} = Repo.insert(cancelled_activity)

      # Verify both work correctly
      loaded_activated = Repo.get!(Activity, saved_activated.id)
      loaded_cancelled = Repo.get!(Activity, saved_cancelled.id)

      assert %Activated{} = loaded_activated.event
      assert %Cancelled{} = loaded_cancelled.event
      assert loaded_activated.event.user_id == 100
      assert loaded_cancelled.event.user_id == 200
      assert loaded_activated.event.activation_code == "ACT-100"
      assert loaded_cancelled.event.reason == "fraud_detected"
    end
  end
end
