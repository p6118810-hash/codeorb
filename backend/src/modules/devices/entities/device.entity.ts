import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn
} from 'typeorm';
import { nullableDateTransformer } from '../../../common/database/nullable-date.transformer';
import { ClientSession } from '../../sessions/entities/client-session.entity';
import { User } from '../../users/entities/user.entity';

@Entity({ name: 'devices' })
@Index(['userId', 'deviceIdentifier'], { unique: true })
export class Device {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'user_id' })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ name: 'device_identifier', type: 'varchar', length: 120 })
  deviceIdentifier!: string;

  @Column({ type: 'varchar', length: 120 })
  name!: string;

  @Column({ type: 'varchar', length: 20 })
  kind!: string;

  @Column({ type: 'varchar', length: 80 })
  platform!: string;

  @Column({ name: 'app_version', type: 'varchar', length: 40, nullable: true })
  appVersion?: string | null;

  @Column({ name: 'build_number', type: 'varchar', length: 40, nullable: true })
  buildNumber?: string | null;

  @Column({ type: 'simple-json', nullable: true })
  metadata?: Record<string, unknown> | null;

  @Column({
    name: 'last_seen_at',
    type: 'integer',
    nullable: true,
    transformer: nullableDateTransformer
  })
  lastSeenAt?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  @OneToMany(() => ClientSession, (session) => session.device)
  sessions?: ClientSession[];
}
