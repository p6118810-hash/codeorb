import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn
} from 'typeorm';
import { nullableDateTransformer } from '../../../common/database/nullable-date.transformer';
import { AuthSession } from '../../auth/entities/auth-session.entity';

@Entity({ name: 'users' })
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'display_name', length: 80 })
  displayName!: string;

  @Column({ type: 'varchar', nullable: true, unique: true })
  @Index()
  email?: string | null;

  @Column({ name: 'password_hash', type: 'varchar', nullable: true })
  passwordHash?: string | null;

  @Column({ name: 'avatar_url', type: 'varchar', nullable: true })
  avatarUrl?: string | null;

  @Column({ default: 'user' })
  role!: string;

  @Column({ name: 'auth_provider', default: 'anonymous' })
  authProvider!: string;

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

  @OneToMany(() => AuthSession, (session) => session.user)
  sessions?: AuthSession[];
}
