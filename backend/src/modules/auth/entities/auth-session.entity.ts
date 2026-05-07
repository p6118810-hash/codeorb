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
import { User } from '../../users/entities/user.entity';

@Entity({ name: 'auth_sessions' })
export class AuthSession {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'token_id', unique: true })
  @Index({ unique: true })
  tokenId!: string;

  @Column({ name: 'user_id' })
  userId!: string;

  @ManyToOne(() => User, (user) => user.sessions, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @Column({ default: 'unknown' })
  source!: string;

  @Column({ name: 'device_id', type: 'varchar', nullable: true })
  deviceId?: string | null;

  @Column({ type: 'simple-json', nullable: true })
  metadata?: Record<string, unknown> | null;

  @Column({
    name: 'last_used_at',
    type: 'integer',
    nullable: true,
    transformer: nullableDateTransformer
  })
  lastUsedAt?: Date | null;

  @Column({
    name: 'revoked_at',
    type: 'integer',
    nullable: true,
    transformer: nullableDateTransformer
  })
  revokedAt?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
