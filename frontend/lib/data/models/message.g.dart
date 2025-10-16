// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 1;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      id: fields[0] as String,
      clientId: fields[1] as String,
      senderId: fields[2] as String,
      receiverId: fields[3] as String,
      messageType: fields[4] as MessageType,
      encryptedContent: fields[5] as String,
      encryptionIv: fields[6] as String,
      mediaUrl: fields[7] as String?,
      mediaThumbnailUrl: fields[8] as String?,
      mediaMetadata: (fields[9] as Map?)?.cast<String, dynamic>(),
      replyToId: fields[10] as String?,
      reactions: (fields[11] as Map).cast<String, List<String>>(),
      isViewOnce: fields[12] as bool,
      selfDestructTimer: fields[13] as int?,
      status: fields[14] as MessageStatus,
      deliveredAt: fields[15] as DateTime?,
      readAt: fields[16] as DateTime?,
      createdAt: fields[17] as DateTime,
      deletedBySender: fields[18] as bool,
      deletedByReceiver: fields[19] as bool,
      deletedForEveryone: fields[20] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.receiverId)
      ..writeByte(4)
      ..write(obj.messageType)
      ..writeByte(5)
      ..write(obj.encryptedContent)
      ..writeByte(6)
      ..write(obj.encryptionIv)
      ..writeByte(7)
      ..write(obj.mediaUrl)
      ..writeByte(8)
      ..write(obj.mediaThumbnailUrl)
      ..writeByte(9)
      ..write(obj.mediaMetadata)
      ..writeByte(10)
      ..write(obj.replyToId)
      ..writeByte(11)
      ..write(obj.reactions)
      ..writeByte(12)
      ..write(obj.isViewOnce)
      ..writeByte(13)
      ..write(obj.selfDestructTimer)
      ..writeByte(14)
      ..write(obj.status)
      ..writeByte(15)
      ..write(obj.deliveredAt)
      ..writeByte(16)
      ..write(obj.readAt)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.deletedBySender)
      ..writeByte(19)
      ..write(obj.deletedByReceiver)
      ..writeByte(20)
      ..write(obj.deletedForEveryone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
