import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn
} from 'typeorm';
import { nullableDateTransformer } from '../../../common/database/nullable-date.transformer';
import { Device } from '../../devices/entities/device.entity';
import { User } from '../../users/entities/user.entity';

@Entity({ name: 'client_sessions' })
@Index(['deviceId', 'externalSessionId'], { unique: true })
export class ClientSession {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ name: 'device_id' })
  deviceId!: string;

  @ManyToOne(() => Device, (device) => device.sessions, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'device_id' })
  device!: Device;

  @Column({ name: 'external_session_id', type: 'varchar', length: 160 })
  externalSessionId!: string;

  @Column({ type: 'varchar', length: 40 })
  provider!: string;

  @Column({ type: 'varchar', length: 200, nullable: true })
  title?: string | null;

  @Column({ type: 'varchar', length: 400, nullable: true })
  cwd?: string | null;

  @Column({ type: 'varchar', length: 80 })
  phase!: string;

  @Column({ name: 'is_focused', type: 'boolean', default: false })
  isFocused!: boolean;

  @Column({ type: 'simple-json', nullable: true })
  metadata?: Record<string, unknown> | null;

  @Column({
    name: 'started_at',
    type: 'integer',
    nullable: true,
    transformer: nullableDateTransformer
  })
  startedAt?: Date | null;

  @Column({
    name: 'last_activity_at',
    type: 'integer',
    nullable: true,
    transformer: nullableDateTransformer
  })
  lastActivityAt?: Date | null;

  @Column({
    name: 'ended_at',
    type: 'integer',
    nullable: true,
    transformer: nullableDateTransformer
  })
  endedAt?: Date | null;

  @Column({
    name: 'archived_at',
    type: 'integer',
    nullable: true,
    transformer: nullableDateTransformer
  })
  archivedAt?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
