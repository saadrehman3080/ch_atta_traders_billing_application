// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_bill.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingBillAdapter extends TypeAdapter<PendingBill> {
  @override
  final int typeId = 11;

  @override
  PendingBill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingBill(
      billId: fields[0] as String,
      customerName: fields[1] as String,
      date: fields[2] as DateTime,
      productsJson: (fields[3] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      discount: fields[4] as int,
      salesmanIdentifier: fields[5] as String,
      billType: fields[6] as String,
      isPaid: fields[7] as bool,
      amountDue: fields[8] as int,
      cratesDue: fields[9] as int,
      partialPaymentsJson: (fields[10] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      createdAt: fields[11] as DateTime,
      syncAttempts: fields[12] as int,
      paymentType: fields[13] as String?,
      schemaVersion: fields[14] as int,
      status: fields[15] as PendingBillStatus,
      lastSyncAttempt: fields[16] as DateTime?,
      isReceiptGenerated: fields[17] as bool? ?? true,
      latitude: (fields[18] as num?)?.toDouble(),
      longitude: (fields[19] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, PendingBill obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.billId)
      ..writeByte(1)
      ..write(obj.customerName)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.productsJson)
      ..writeByte(4)
      ..write(obj.discount)
      ..writeByte(5)
      ..write(obj.salesmanIdentifier)
      ..writeByte(6)
      ..write(obj.billType)
      ..writeByte(7)
      ..write(obj.isPaid)
      ..writeByte(8)
      ..write(obj.amountDue)
      ..writeByte(9)
      ..write(obj.cratesDue)
      ..writeByte(10)
      ..write(obj.partialPaymentsJson)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.syncAttempts)
      ..writeByte(13)
      ..write(obj.paymentType)
      ..writeByte(14)
      ..write(obj.schemaVersion)
      ..writeByte(15)
      ..write(obj.status)
      ..writeByte(16)
      ..write(obj.lastSyncAttempt)
      ..writeByte(17)
      ..write(obj.isReceiptGenerated)
      ..writeByte(18)
      ..write(obj.latitude)
      ..writeByte(19)
      ..write(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingBillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PendingBillStatusAdapter extends TypeAdapter<PendingBillStatus> {
  @override
  final int typeId = 10;

  @override
  PendingBillStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PendingBillStatus.pending;
      case 1:
        return PendingBillStatus.syncing;
      case 2:
        return PendingBillStatus.failed;
      case 3:
        return PendingBillStatus.synced;
      default:
        return PendingBillStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, PendingBillStatus obj) {
    switch (obj) {
      case PendingBillStatus.pending:
        writer.writeByte(0);
        break;
      case PendingBillStatus.syncing:
        writer.writeByte(1);
        break;
      case PendingBillStatus.failed:
        writer.writeByte(2);
        break;
      case PendingBillStatus.synced:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingBillStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
